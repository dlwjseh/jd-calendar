import Foundation

// 한국천문연구원_특일 정보 API 의 한 항목(공휴일).
// API 응답을 우리가 다루기 좋은 값 타입으로 정규화한 결과.
struct KASIHoliday: Equatable {
    // 휴일 이름. 예: "설날", "어린이날", "대체공휴일".
    let dateName: String
    // 해당 휴일의 날짜. 시각은 시스템 timeZone 기준 00:00 (종일 이벤트로 저장하기 위함).
    let date: Date
}

// API 호출 중 발생할 수 있는 에러.
enum KASIError: Error {
    case missingKey
    case invalidURL
    case http(Int)
    case decodingFailed(String)
    case networkFailed(Error)
}

// 공공데이터포털 — 한국천문연구원_특일 정보 (getRestDeInfo) 클라이언트.
// 공휴일 + 대체공휴일을 함께 돌려준다.
//
// 발급/등록은 https://data.go.kr → "한국천문연구원_특일 정보" → 활용신청.
// 인증키는 Secrets.xcconfig → KASI_SERVICE_KEY 로 주입되며, AppSecrets 에서 읽는다.
enum KASIClient {

    // 베이스 URL — HTTPS 사용으로 ATS 예외 불필요.
    private static let baseURL = "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo"

    // 한 해의 공휴일을 모두 가져온다.
    // 한국 공휴일은 한 해 평균 ~17건이라 numOfRows=100 한 페이지면 충분하다.
    static func fetchHolidays(year: Int) async throws -> [KASIHoliday] {
        guard let key = AppSecrets.kasiServiceKey else {
            throw KASIError.missingKey
        }

        // serviceKey 는 보통 이미 percent-encoded 상태 (data.go.kr "Encoding 키" 사용 시).
        // URLComponents.queryItems 는 자동으로 한 번 더 인코딩하므로 깨진다 → 문자열로 직접 조립.
        // 키가 raw 형태(% 미포함)라면 한 번만 인코딩.
        let encodedKey = key.contains("%")
            ? key
            : (key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)

        let urlString = "\(baseURL)?serviceKey=\(encodedKey)&solYear=\(year)&numOfRows=100&_type=json"
        guard let url = URL(string: urlString) else {
            throw KASIError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw KASIError.networkFailed(error)
        }

        // 2xx 가 아니면 에러로 처리. data.go.kr 는 가끔 정상 200 + 바디 에러 메시지를 주기도 하는데
        // 그 경우는 parse() 단에서 decodingFailed 로 떨어진다.
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw KASIError.http(http.statusCode)
        }

        return try parse(data: data)
    }

    // 응답 JSON 을 [KASIHoliday] 로 변환.
    //
    // 응답 형태(요약):
    //   { response: { body: { items: { item: [{...}, {...}] }, totalCount: 15 } } }
    //
    // 정부 API 의 흔한 함정들:
    //   1) totalCount=0 일 때 items 가 빈 문자열("") 로 옴
    //   2) totalCount=1 일 때 item 이 배열이 아니라 단일 객체로 옴
    //   3) locdate 가 Int 또는 String 으로 옴
    // → JSONSerialization 으로 동적 파싱해 모두 방어적으로 처리.
    private static func parse(data: Data) throws -> [KASIHoliday] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = root["response"] as? [String: Any],
              let body = response["body"] as? [String: Any] else {
            // 구조가 다르면 디버깅 위해 본문 일부 노출.
            let preview = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw KASIError.decodingFailed(String(preview))
        }

        // totalCount 0 이면 빈 배열로 종료.
        let totalCount: Int = {
            if let i = body["totalCount"] as? Int { return i }
            if let s = body["totalCount"] as? String, let i = Int(s) { return i }
            return 0
        }()
        if totalCount == 0 { return [] }

        // items 가 빈 문자열인 경우(휴일 0건의 또 다른 표현) 도 빈 배열.
        guard let items = body["items"] as? [String: Any], let itemRaw = items["item"] else {
            return []
        }

        // item 은 배열(다건) 또는 단일 객체(1건).
        let dictArray: [[String: Any]]
        if let arr = itemRaw as? [[String: Any]] {
            dictArray = arr
        } else if let single = itemRaw as? [String: Any] {
            dictArray = [single]
        } else {
            return []
        }

        // YYYYMMDD → Date 변환. 시스템 timeZone(보통 Asia/Seoul) 기준 00:00 으로 만들어
        // 앱 내 다른 종일 이벤트와 동일한 표현을 가진다.
        let calendar = Calendar(identifier: .gregorian)

        return dictArray.compactMap { dict -> KASIHoliday? in
            guard let dateName = dict["dateName"] as? String else { return nil }

            // locdate 는 Int 또는 String.
            let locdateInt: Int
            if let i = dict["locdate"] as? Int {
                locdateInt = i
            } else if let s = dict["locdate"] as? String, let i = Int(s) {
                locdateInt = i
            } else {
                return nil
            }

            // isHoliday "Y" 만 채택 — getRestDeInfo 는 휴일만 돌려주지만 방어적으로 한 번 더 체크.
            let isHoliday = (dict["isHoliday"] as? String) ?? "Y"
            guard isHoliday == "Y" else { return nil }

            // 8자리 정수에서 year/month/day 추출.
            let y = locdateInt / 10_000
            let m = (locdateInt / 100) % 100
            let d = locdateInt % 100
            guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
                return nil
            }
            return KASIHoliday(dateName: dateName, date: date)
        }
    }
}
