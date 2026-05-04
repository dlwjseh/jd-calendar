import Foundation

// Info.plist 경유로 주입되는 앱 시크릿(API 키 등)을 읽기 위한 헬퍼.
//
// 주입 경로:
//   Secrets.xcconfig
//     └─ KASI_SERVICE_KEY = ...
//   Build Settings (User-Defined)
//     └─ INFOPLIST_KEY_KASIServiceKey = $(KASI_SERVICE_KEY)
//   자동 생성된 Info.plist
//     └─ KASIServiceKey = ...
//   Bundle.main.object(forInfoDictionaryKey: "KASIServiceKey")
//
// enum 으로 선언한 이유: 인스턴스화 막고 네임스페이스로만 쓰기 위해.
enum AppSecrets {

    // 공공데이터포털 한국천문연구원 특일정보 API 인증키 (Encoding 키).
    // 키가 비어 있거나 누락되면 nil 반환 — 호출 측에서 "키 미설정" 상태를 결정.
    static var kasiServiceKey: String? {
        // Info.plist 에서 문자열로 꺼내고, 공백만 들어 있는 경우도 누락으로 간주.
        let raw = Bundle.main.object(forInfoDictionaryKey: "KASIServiceKey") as? String
        guard let key = raw?.trimmingCharacters(in: .whitespaces), !key.isEmpty else {
            return nil
        }
        return key
    }
}
