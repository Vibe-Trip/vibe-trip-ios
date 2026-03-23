# Vibe-Trip iOS App
> 

## 프로젝트 소개



## ⚒️ 기술 스택

| 분류 | 기술 |
|------|------|
| **Language** | Swift |
| **UI** | SwiftUI |
| **Architecture** | MVVM |
| **Reactive** | Combine |
| **IDE** | Xcode |
| **iOS** | 16.0+ |

## 🗂️ 프로젝트 구조

```
VibeTrip/
├── VibeTripApp.swift
├── Models/
├── Views/
├── ViewModels/
├── Services/
├── Resources/
└── Extensions/
```

## 📌 브랜치 전략

| 브랜치 | 용도 | 병합 대상 |
|--------|------|------|
| `main` | 앱스토어 출시용 |  |
| `release` | 개발 완료 | `main`, `develop` |
| `develop` | 개발 완료 | `release` |
| `feature` | 기능 개발 | `develop` |
| `hotfix` | 배포 버전 버그 수정 | `main` |

## 📌 커밋 컨벤션

| 태그 | 설명 |
|------|------|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `chore` | 빌드, 패키지 등 기타 작업 |
| `refactor` | 코드 리팩토링 |
| `docs` | 문서 수정 |
| `test` | 테스트 코드 작성·수정|
