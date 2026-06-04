# Vibe-Trip iOS App
> 사진이 음악이 되는 여행 아카이브 iOS App

[![App Store](https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white)](https://apps.apple.com/kr/app/retrip-%EB%8B%A4%EC%8B%9C-%EB%93%A3%EB%8A%94-%EB%82%98%EC%9D%98-%EC%97%AC%ED%96%89-%EA%B8%B0%EB%A1%9D/id6760816556)



<img width="1920" height="1080" alt="retripThumbnail" src="https://github.com/user-attachments/assets/e354cec8-65ff-4530-a378-173e474335e2" /> 



## 프로젝트 소개
Hear Your Trip Again → "잊히지 않을 나만의 여행 사운드트랙"

RETRIP은 사진, 여행지, 장르를 입력하면 AI가 사진의 색감과 분위기를 분석해서 <br>
세상에 하나뿐인 음악을 생성해주는 서비스입니다. <br>
음악과 사진, 기록이 하나의 앨범으로 아카이빙되어 언제든 다시 꺼내 들을 수 있습니다.


## ⚒️ 기술 스택

| 분류 | 기술 |
|------|------|
| **Language** | Swift |
| **UI** | SwiftUI |
| **Architecture** | MVVM |
| **Reactive** | Combine |
| **IDE** | Xcode |
| **iOS** | 17.0+ |
| **Dependency** | Swift Package Manager |

## 🗂️ 프로젝트 구조

```
vibe-trip-ios/
├── VibeTrip/
│   ├── App/                      # 앱 진입점·전역 상태
│   ├── Core/                     # 전역 인프라
│   │   ├── Network/              # APIClient
│   │   ├── Config/               # AppConfig
│   │   ├── Storage/              # KeychainService
│   │   ├── Auth/                 # 인증 서비스 
│   │   ├── Analytics/            # 분석 서비스 + AnalyticsEvent
│   │   ├── Media/                # 음악재생 서비스
│   │   └── Models/               # 공통 모델 
│   ├── Features/                 # 기능별 모듈
│   │   ├── Auth/                 
│   │   ├── Album/                
│   │   ├── MyPage/               
│   │   └── Notification/         
│   ├── Shared/                   # 범용 요소
│   │   ├── Components/           # 공통 UI
│   │   │   ├── Modifiers/        # ViewModifier·View 확장
│   │   │   ├── Representables/   # UIKit 래퍼
│   │   │   ├── Overlays/         # 토스트·팝업·배너
│   │   │   └── NavigationBar/    
│   │   └── Extensions/           # 공통 확장 (Font+Pretendard 등)
│   ├── Resources/                
│   ├── Assets.xcassets/          
│   ├── Info.plist
│   ├── GoogleService-Info.plist  # gitignore 처리
│   ├── PrivacyInfo.xcprivacy
│   └── VibeTrip.entitlements
├── VibeTripTests/                
├── VibeTripUITests/
├── Config/                       # 빌드 설정 (xcconfig, Firebase Debug/Release)
└── ci_scripts/                   
```

## 📌 브랜치 전략

| 브랜치 | 용도 | 병합 대상 |
|--------|------|------|
| `main` | 앱스토어 출시용 |  |
| `release` | 출시 준비 | `main`, `develop` |
| `hotfix` | 배포 버전 버그 수정 | `main`, `develop` |
| `develop` | 개발 완료 | `release` |
| `feature` | 기능 개발 | `develop` |

## 📌 커밋 컨벤션

| 태그 | 설명 |
|------|------|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `chore` | 빌드, 패키지 등 기타 작업 |
| `refactor` | 코드 리팩토링 |
| `docs` | 문서 수정 |
| `test` | 테스트 코드 작성·수정|
