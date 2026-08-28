# VibeTrip iOS 프로젝트

## 프로젝트 개요
여행 사진을 분석(사진의 분위기) 및 사용자가 입력한 정보(음악 장르, 여행지, 여행기간, 가사 포함 여부)를 기반으로 AI를 이용해 음악을 생성하는 iOS 앱.

---

## iOS 기술 스택
- 언어: Swift
- UI 프레임워크: SwiftUI
- 아키텍처: MVVM
- 반응형: Combine (iOS 17+)
- 최소 지원: iOS 17+
- onChange 클로저 파라미터만 (oldValue, newValue) 형태
- 상태관리 방식: @Published + ObservableObject
- 아이콘: SF Symbols

## 외부 SDK
- Firebase (FirebaseCore, FCM)
- KakaoSDK (KakaoSDKCommon, KakaoSDKAuth, KakaoSDKUser)

## 백엔드 기술 스택
- 언어: Kotlin / Spring Boot
- DB: MySQL
- API 문서: Swagger
- 클라우드: Google Cloud Platform
- Push 알림: APNs + Firebase Cloud Messaging

---

## 아키텍처 규칙
- View → ViewModel → Model 레이어 엄격히 분리
- ViewModel에서 비즈니스 로직 처리, View는 UI만
- 모델 파일명: AuthModel, ProfileModel (AuthService, UserModel 금지)
- 네트워크/비즈니스 로직: async/await 사용
- 상태 바인딩: @Published + @StateObject/@ObservedObject 기본 사용
- Combine sink/assign: 값이 바뀔 때 자동으로 추가 작업이 필요한 경우에만 사용 (예: 검색 디바운싱, 실시간 스트림)
- 서비스 레이어는 Protocol 기반으로 작성 


## 디자인 시스템
- Primary 색상: #2D36D1 → `Color.appPrimary` (Assets Color Set + Extension 방식)
- 폰트: Pretendard → `Font.setPretendard(weight:size:)` Extension 방식
- 색상은 Assets Color Set으로 관리 (추후 다크모드 대응 염두)

## 네이밍 규칙
- ViewModel: `{기능}ViewModel` (예: LoginViewModel, TripViewModel)
- View: `{기능}View` (예: LoginView, TripListView)
- Model: `{기능}Model` (예: AuthModel, TripModel)
- Protocol: `{기능}Protocol`
- enum case: camelCase

## 코드 작성 규칙
- 확장성과 재사용성을 항상 염두에 두고 구현
- UI 구성 시 값이 불명확하면 임의로 지정하지 말고 추가 정보 요청
- 단위 테스트 가능한 구조일 경우 구현 여부 먼저 질문
- SwiftUI Preview 항상 포함
- 접근 제어자 명시 (private, internal 등)
- 매직 넘버 사용 금지 → 상수로 분리

---

## 작업 방식
- 작업 전 반드시 무엇을 왜 할지 설명하고 승인 후 진행 (규모 무관)
- 채팅 메시지는 구조화된 방식으로 보여줄 것.
- 플랜 제시 시 작업 단계뿐 아니라 변경 후 앱 플로우를 케이스 표로 함께 제시
  - 구성: 핵심 동작 규칙 요약 → 플로우 단계별 그룹(앱 실행 / 화면 진입 / 화면 내부 / 이탈 / 시스템 이벤트) → 케이스별 결과
  - 각 케이스는 추측이 아닌 실제 코드 경로를 확인한 뒤 작성하고, 근거를 파일:라인으로 표기
  - 진입 경로가 여러 개인 기능은 경로별로 가드 유무를 각각 확인 (예: 목록 탭 / 알림 딥링크)
  - 코드로 확정할 수 없는 항목은 단정하지 말고 "실기기 확인 필요"로 명시
  - 사용자 결정이 필요한 분기는 표 밖으로 분리해 선택지와 트레이드오프를 함께 제시
- 사용자가 작업 요청을 직접적으로 한 경우 제외하고는 임의로 작업 진행하지 말고 플랜 모드 제시할 것.
- 커밋은 사용자가 직접 진행 → 커밋이 필요할 때는 메시지(제목 + 본문)만 제안. 이때 제목은 기능적으로(예: feat: 로그인 기능 추가)
- 커밋 메시지는 "제목 1줄 + 본문 불릿" 형식으로 작성
- 구현은 커밋으로 순서대로 구현한 것처럼 보일 수 있도록 필요할 경우에만 단계별로 세분화해서 진행하고 한 파일에 대해서도 필요할 경우 세분화 해서 나눠서 단계별로 진행. 

## Git 규칙
- 브랜치 전략: GitHub Flow (`feature/기능명`, `fix/버그명`)
- 커밋 컨벤션: feat: 새로운 기능 추가 / fix: 버그 수정 / refactor: 코드 리팩토링 / chore: 빌드, 패키지 등 기타 작업 / docs: 문서 수정/ test:테스트 코드 작성 및 수정 
- 커밋 메시지(제목): 한국어, 구현 방법(어떻게)이 아닌 목적/효과(왜, 뭐가 달라지는지) 중심으로 작성
  - 예) ❌ `chore: MockBackendAuthService #if DEBUG 조건부 컴파일 적용`
  - 예) ✅ `chore: Mock 서비스 릴리즈 빌드에서 제외`
- 커밋 메시지(본문): 여러 파일일 경우 파일별로 나눠서 작성. 구현한 기능에 대해서 코드 및 함수명은 주석으로 확인가능하니 기능위주로 서술할 것

---

## 주의사항
- Xcode 26 기준
- Privacy Manifest 포함 필수
- App Store 심사 기준 준수 (개인정보처리방침 및 이용약관은 로그인 후 마이페이지에서 노출)
- 커스텀 탭바 사용 (iOS 17+ 지원으로 네이티브 탭바 미사용, Liquid Glass 비적용)
- 기존 주석은 스타일 수정과 같이 내용이 틀린 경우가 아닐 때는 수정하지 말것
- 파일 생성 시 파일 내용 주석은 아래와 같이 작성:
//
//  파일명.swift
//  VibeTrip
//
//  Created by CHOI on 생성 날짜(예: 3/21/26).
//
