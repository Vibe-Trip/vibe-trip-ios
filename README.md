


# RETRIP - iOS App
> 사진이 음악이 되는 여행 아카이빙 iOS 앱

<a href="https://apps.apple.com/kr/app/id6760816556">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="App Store에서 다운로드" height="40" />
</a>

<p align="center">
  <img src="https://github.com/user-attachments/assets/e354cec8-65ff-4530-a378-173e474335e2" width="100%" alt="리트립 썸네일"/>
</p>

---

### 📱 프로젝트 소개

**리트립(RETRIP)** 은 사진과 여행지, 장르를 입력하면 AI가 사진의 색감과 분위기를 분석해 **하나뿐인 음악을 생성**하고, 그 음악과 함께 여행을 기록하는 여행 아카이빙 앱입니다. <br>
생성된 음악과 함께 지난 여행을 다시 꺼내 보세요.



---

### ✨ 주요 기능

- **앨범 생성** - 사진·여행지·장르를 고르면 분위기에 맞는 음악이 생성되어 앨범으로 저장됩니다.
  > `FCM` 푸시 · `폴링` 하이브리드 - 알림 권한 상태에 따라 완료 감지 경로 분기
- **여행 기록** - 앨범 안에 사진과 글로 기록을 남기고 수정·삭제할 수 있습니다.
  > `multipart` 업로드 · `cursor` 페이지네이션으로 목록 이어받기
- **음악 재생** - 앨범 내에서 끊기지 않고 재생되며, 생성된 음악은 다운로드 받을 수 있습니다.
  > `AVFoundation` 전역 재생 서비스 · 재생 전용 오디오 세션
- **소셜 로그인** - 카카오·Apple 계정으로 별도 가입 절차 없이 시작합니다.
  > `JWT`를 `Keychain`에 저장 · 갱신 실패를 만료와 일시 오류로 분기

---

### 🖥️ 화면 구성

<table align="center" width="100%">
  <tr align="center">
    <td width="33.33%"><img src="https://github.com/user-attachments/assets/51a7a682-381b-4919-b86e-384079b52842" width="220" alt="홈"></td>
    <td width="33.33%"><img src="https://github.com/user-attachments/assets/6feca2e1-ce38-4e6c-9ddc-ce89d26d2ce4" width="220" alt="앨범 상세"></td>
    <td width="33.33%"><img src="https://github.com/user-attachments/assets/cd9a4f96-e2f1-4061-ab1e-017f74f6ab64" width="220" alt="여행 기록"></td>
  </tr>
  <tr align="center">
    <td width="33.33%"><img src="https://github.com/user-attachments/assets/5ac0984d-41d4-46ea-b2d9-abd598bc4cf4" width="220" alt="앨범 생성 (필수)"></td>
    <td width="33.33%"><img src="https://github.com/user-attachments/assets/c2594f23-f14e-4d03-8220-37cba69e8ed3" width="220" alt="앨범 생성 (선택)"></td>
    <td width="33.33%"><img src="https://github.com/user-attachments/assets/316f8245-91cb-4f14-b9a7-7de8abf20866" width="220" alt="생성 대기"></td>
  </tr>
</table>

---

### 🏗️ 시스템 아키텍처

<p align="center">
  <img src="https://github.com/user-attachments/assets/660b8283-fb9e-406d-9de2-35b5d29d2a58" width="100%" alt="리트립 시스템 아키텍처"/>
</p>

> 서버 레포 - [vibe-trip-server](https://github.com/Vibe-Trip/vibe-trip-server)

---

### ⚒️ 기술 스택

| 분류 | 기술 |
|------|------|
| **Language** | Swift 5 |
| **UI Framework** | SwiftUI (UIViewRepresentable 혼용) |
| **Architecture** | Feature-first MVVM |
| **Concurrency** | Swift Concurrency (async/await, Actor), Combine |
| **Media** | AVFoundation, PhotosUI |
| **Push & Analytics** | Firebase Cloud Messaging, UserNotifications, Firebase Analytics |
| **Auth** | Kakao SDK, Sign in with Apple, JWT, Keychain |
| **Test** | XCTest |
| **Project & Dependency** | Swift Package Manager, xcconfig (Debug / Release) |
| **CI/CD** | Xcode Cloud |
| **Deployment Target** | iOS 17.0+ |

---

### 🗂️ 프로젝트 구조

```
vibe-trip-ios/                     # 레포 루트
├── VibeTrip.xcodeproj             # Xcode 프로젝트 · SPM 의존성 · 스킴 3종(Dev / Prod / 기본)
├── VibeTrip.xctestplan            # 테스트 플랜
├── Config/                        # 빌드 설정(Debug / Release.xcconfig) · Firebase 설정(Debug / Release)
├── ci_scripts/                    # Xcode Cloud post-clone 스크립트
├── .github/                       # 이슈 · PR 템플릿 · Release Drafter 워크플로
├── VibeTripTests/                 # 단위 테스트 · Mock 객체
│
└── VibeTrip/                      # 앱 타겟
    ├── App/                       # 앱 진입점 · 전역 상태 · 스플래시 / 탭바
    ├── Core/                      # 전역 인프라 - 네트워크 / Keychain / 인증(Apple·Kakao) / 분석 / 음악 재생 / 환경값(AppConfig)
    ├── Features/                  # 기능 모듈 - 앨범 / 로그인 / 마이페이지 / 알림 (Model · ViewModel · View · Service)
    ├── Shared/                    # 공용 UI - 커스텀 NavigationBar · Overlay · Modifier · UIViewRepresentable 래퍼 · 폰트 확장
    ├── Resources/                 # 폰트 파일(Pretendard) · 앨범 생성 영상
    └── Assets.xcassets            # 이미지 · 컬러 에셋
```

---

## 🔍 문제 해결

### 1. 음악 생성 완료 감지에서 모든 사용자가 반복 폴링으로 서버를 조회하던 문제, 알림 권한 기준 하이브리드로 해결

<img width="90%" alt="음악 생성 완료 감지" src="https://github.com/user-attachments/assets/45e91990-284d-466f-9840-769b21caf0bc"/> <br>

**📍 제약 상황**

- 생성 중 앨범이 있는 동안 모든 사용자가 앨범당 `5초` 간격·최대 `120회` 조회
- 앱을 벗어나면 완료를 감지하지 못해 카드가 `스켈레톤`에 머무름
- 완료를 확인할 경로가 앨범 단건 조회 폴링뿐 → **서버가 보내는 완료 신호를 받을 구조가 없음**

**⚖️ 선택한 구조와 이유**

푸시만 쓰면 알림 권한을 거부한 사용자에게 스켈레톤이 영구적으로 남습니다. <br>폴링만 쓰면 푸시로 받을 수 있는 사용자까지 서버를 계속 확인합니다. <br>어느 한쪽을 고르든 반대편 사용자가 손해를 보는 구조였습니다. <br>**신호를 받는 방법은 사용자마다 달라도 되지만 도달하는 상태는 같아야 한다고 봤습니다.**

**✅ 결과**

- 알림 권한 허용이면 진입 시 `단건 확인` 1회 후 `FCM` 푸시로 완료 수신 - 허용 사용자의 반복 폴링 제거
- 미허용이면 즉시 반복 폴링 시작 - 권한을 거부한 사용자도 같은 시점에 완료 도달
- 단건 확인 실패 시 권한과 무관하게 폴링으로 폴백 - 앱을 벗어났다 돌아와도 카드가 스켈레톤에 머물지 않음
- 세 경로의 완료 처리를 하나의 진입점으로 수렴 - 완료 판정 기준이 `음악 URL 존재 여부` 하나로 고정

<details>
<summary>근거</summary>

- 코드 - [`MainPageViewModel.swift:173-258`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/Features/Album/ViewModels/MainPageViewModel.swift#L173-L258)(권한 분기·폴백·완료 수렴) · [`MainTabBarView.swift:117-121`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/App/MainTabBarView.swift#L117-L121)(포그라운드 완료 수신) · [`VibeTripApp.swift:116-132`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/App/VibeTripApp.swift#L116-L132)(푸시 페이로드 분기) · [`AlbumCardView.swift:104-111`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/Features/Album/Components/AlbumCardView.swift#L104-L111)(스켈레톤)
- 커밋 - [`5dd916a`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/5dd916a) [`6c78124`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/6c78124) [`94a2b31`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/94a2b31) [`1144d10`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/1144d10)
- 검증 - `MainPageViewModelTests.swift` 완료 처리 5건 · 권한 분기 2건

</details>

---

### 2. 인증 세션 유지에서 일시적 네트워크 장애만으로 강제 로그아웃되던 문제, 갱신 결과를 성공·만료·일시 오류로 분기해 해결

<img width="90%" alt="토큰 갱신 결과 분기" src="https://github.com/user-attachments/assets/71a3717d-6e22-4265-a855-b92797aa40fb"/> <br>

**📍 제약 상황**

- 네트워크 단절·서버 일시 오류로 갱신이 실패해도 만료로 판정 → `Keychain` 토큰 삭제 후 로그인 화면 강제 이동
- 동시에 여러 요청이 401을 받으면 갱신 요청도 그 수만큼 발생
- `401` 응답을 refresh token 만료 한 가지 결과로만 처리 → **갱신 요청이 왜 실패했는지 구분할 지점이 없음**

**⚖️ 선택한 구조와 이유**

401을 곧바로 로그아웃으로 처리하면 구현은 단순하지만 일시 장애까지 세션 종료로 취급하게 됩니다. <br>반대로 무조건 재시도하면 이미 만료된 세션을 계속 붙잡습니다. <br>두 선택지 모두 "실패했다"는 사실 하나만 보고 판단하기 때문입니다. <br>**세션을 끝낼 권한은 서버에만 두기로 했습니다.**

**✅ 결과**

- 갱신 결과를 `성공·만료·일시 오류` 세 타입으로 분리 - 네트워크 단절·서버 일시 오류로 인한 강제 로그아웃 제거
- 만료 판정을 서버가 `401·403`으로 명시한 경우로 한정 - 일시 장애 구간에서 재로그인 없이 세션 유지
- 갱신을 액터 한 곳에서만 수행하고 대기열에 같은 결과를 배포 - 동시 발생한 다중 401에서 갱신 요청이 `1회`로 수렴
- 만료·일시 오류·갱신 성공 세 시나리오의 로그아웃 여부와 재시도 동작을 단위 테스트로 고정

<details>
<summary>근거</summary>

- 코드 - [`APIClient.swift:153-191`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/Core/Network/APIClient.swift#L153-L191)(결과 타입·갱신 액터) · [`:267-303`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/Core/Network/APIClient.swift#L267-L303)(401 인터셉터) · [`:317-348`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/Core/Network/APIClient.swift#L317-L348)(갱신 요청) · [`AppState.swift:94-100`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/App/AppState.swift#L94-L100)(세션 만료 구독)
- 커밋 - [`48e0a1f`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/48e0a1f) [`b7361c8`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/b7361c8) [`d08916e`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/d08916e) [`393e16b`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/393e16b)
- 검증 - `APIClientTests.swift` 갱신 결과 분기 3건

</details>

---

### 3. 개발·배포 환경 분리에서 설정 파일 복사가 자동 리소스 복사와 겹쳐 아카이브 빌드가 실패하던 문제, 번들 반입 경로 일원화로 해결

<img width="90%" alt="빌드 구성별 설정 주입" src="https://github.com/user-attachments/assets/48f81000-039a-4453-b922-72501852f695"/> <br>

**📍 제약 상황**

- 서버 URL과 카카오 앱 키가 소스에 하드코딩 → 빌드 구성별로 다른 값을 주입할 지점 없음
- `GoogleService-Info.plist`가 동기화 폴더를 통해 타깃 리소스로 자동 포함
- 설정 파일을 스크립트로 복사하기 시작하자 **같은 파일이 자동 리소스 복사와 복사 스크립트 양쪽에서 번들에 들어감** → 아카이브 빌드가 중복 출력·순환 의존으로 실패

**⚖️ 선택한 구조와 이유**

타깃을 개발용·배포용으로 복제하면 설정은 갈라지지만 이후 모든 빌드 설정을 각각 관리해야 합니다. <br>빌드가 실패한 진짜 이유는 설정이 갈라지지 않아서가 아니라, 한 파일이 번들로 들어가는 경로가 둘이었기 때문입니다. <br>**한 파일이 번들에 들어가는 경로를 하나로 줄이기로 했습니다.**

**✅ 결과**

- 설정 파일을 자동 포함 대상에서 제외하고 번들 반입을 복사 스크립트로 일원화 - 아카이브 빌드의 중복 출력·순환 의존 해소
- 서버 URL·카카오 키·번들 ID를 빌드 구성별 `xcconfig`에 정의해 `Info.plist` 변수로 전달 - 배포 직전 값을 손으로 교체하던 절차가 `스킴 전환` 하나로 축소
- 코드에서는 `AppConfig` 한 곳으로만 읽고 값이 비면 즉시 중단 - 개발 환경 값으로 배포되는 경로 차단
- 복사 스크립트는 소스가 없으면 확인 경로와 함께 실패하고, 클라우드 빌드는 `post-clone`이 환경 변수로 같은 자리에 파일을 생성 - 설정 누락이 런타임까지 가지 않고 빌드 단계에서 드러남

<details>
<summary>근거</summary>

- 코드 - [`AppConfig.swift:10-41`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/VibeTrip/Core/Config/AppConfig.swift#L10-L41)(환경값 진입점·누락 시 중단)
- 설정 - [`Config/Debug.xcconfig`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/Config/Debug.xcconfig) · [`Config/Release.xcconfig`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/Config/Release.xcconfig) · [`ci_scripts/ci_post_clone.sh`](https://github.com/Vibe-Trip/vibe-trip-ios/blob/a8b00f00f423d6ebc6152154ed69fb5ffc4210d4/ci_scripts/ci_post_clone.sh)
- 커밋 - [`9ec5112`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/9ec5112) [`c7d6cde`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/c7d6cde) [`42f34bb`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/42f34bb) [`500f7de`](https://github.com/Vibe-Trip/vibe-trip-ios/commit/500f7de)

</details>

---

## 📌 브랜치 전략

| 브랜치 | 용도 | 병합 대상 |
|--------|------|------|
| `main` | 앱스토어 출시용 | — |
| `release` | 출시 준비 | `main`, `develop` |
| `hotfix` | 배포 버전 버그 수정 | `main`, `develop` |
| `develop` | 개발 완료 | `release` |
| `feature` | 기능 개발 | `develop` |
| `fix` | 버그 수정 | `develop` |
| `refactor` | 코드 리팩토링 | `develop` |
| `chore` | 빌드, 패키지 등 기타 작업 | `develop` |

## 📌 커밋 컨벤션

| 태그 | 설명 |
|------|------|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `chore` | 빌드, 패키지 등 기타 작업 |
| `refactor` | 코드 리팩토링 |
| `docs` | 문서 수정 |
| `test` | 테스트 코드 작성·수정|
