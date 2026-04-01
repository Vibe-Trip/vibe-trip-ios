//
//  AlbumServiceProtocol.swift
//  VibeTrip
//
//  Created by CHOI on 3/24/26.
//

import Foundation

// MARK: - AlbumServiceProtocol

/// 앨범 관련 네트워크 서비스 인터페이스
/// Auth 레이어(AuthServiceProtocol)와 동일한 Protocol 기반 패턴 적용
protocol AlbumServiceProtocol {
    /// 앨범 목록 조회 (커서 기반 페이지네이션)
    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload
    /// 앨범 생성
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse
    /// 앨범 로그 조회
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog
    /// 앨범 정보 수정
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard
    /// 앨범 삭제
    func deleteAlbum(albumId: String) async throws
    /// 로그 저장 (작성/수정 공통)
    func saveLog(request: AlbumLogRequest) async throws -> AlbumLog
}

// MARK: - AlbumCreateRequest / AlbumCreateResponse

struct AlbumCreateRequest {
    let photoData: Data
    let location: String
    let startDate: Date
    let endDate: Date
    let lyricsOption: LyricsOption
    let vocalGender: VocalGender?
    let genre: AlbumGenre
    let comment: String
}

struct AlbumCreateResponse: Decodable {
    let albumId: Int
}

// MARK: - AlbumCreateRequestBody

// multipart request 파트
private struct AlbumCreateRequestBody: Encodable {
    let region: String
    let travelStartDate: String
    let travelEndDate: String
    let genre: String
    let withLyrics: Bool
    let vocalGender: String
    let comment: String
}

// MARK: - AlbumService

final class AlbumService: AlbumServiceProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload {
        // cursor: 존재 ->해당 albumId 이후부터, 존재X -> 첫 페이지부터 조회
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: String(cursor)))
        }
        let endpoint = APIEndpoint(path: "/api/v1/albums", method: .get, queryItems: queryItems)
        return try await apiClient.request(endpoint)
    }

    // 커버 이미지 + 앨범 정보: multipart/form-data로 전송해 앨범 생성
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse {
        // 서버 필드명 기준으로 JSON 파트 구성
        let body = AlbumCreateRequestBody(
            region: request.location,
            travelStartDate: Self.dateFormatter.string(from: request.startDate),
            travelEndDate: Self.dateFormatter.string(from: request.endDate),
            genre: request.genre.serverValue,
            withLyrics: request.lyricsOption == .include,
            // 가사 없음(nil): vocalGender: "N", 가사 있음: "M"/"F"
            vocalGender: request.vocalGender?.serverValue ?? "N",
            comment: request.comment
        )
        var formData = MultipartFormData()
        try formData.append(name: "request", encodable: body)
        formData.append(name: "coverImage", imageData: request.photoData)

        let endpoint = APIEndpoint(path: "/api/v1/albums", method: .post)
        return try await apiClient.upload(endpoint, formData: formData)
    }
    
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog {
        fatalError("TODO: 로그 조회 API 엔드포인트 확인 후 구현")
    }
    
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard {
        fatalError("TODO: 서버 스펙 확정 후 구현")
    }
    
    func deleteAlbum(albumId: String) async throws {
        fatalError("TODO: 서버 스펙 확정 후 구현")
    }
    
    func saveLog(request: AlbumLogRequest) async throws -> AlbumLog {
        fatalError("TODO: 서버 스펙 확정 후 구현")
    }

    // 서버 요구 날짜 포맷
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - MockAlbumService (DEBUG 전용)

#if DEBUG
final class MockAlbumService: AlbumServiceProtocol {
    
    var simulatedError: AlbumError? = nil   // simulatedError: 에러 시나리오 테스트
    var isEmpty: Bool = false              // isEmpty: 빈 목록 테스트
    var delay: UInt64 = 500_000_000       // 응답 지연 시뮬레이션(0.5초)
    
    func fetchAlbums(cursor: Int?, limit: Int) async throws -> AlbumListPayload {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        if isEmpty { return AlbumListPayload(content: [], totalCount: 0, hasNext: false) }
        return AlbumListPayload(
            content: AlbumCard.mockItems,
            totalCount: AlbumCard.mockItems.count,
            hasNext: false
        )
    }
    
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        return AlbumCreateResponse(albumId: 1)
    }
    
    func fetchAlbumLog(albumId: String) async throws -> AlbumLog {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        return AlbumLog.mock
    }
    
    func updateAlbum(albumId: String, request: AlbumUpdateRequest) async throws -> AlbumCard {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        return AlbumCard.mockItems[0]
    }
    
    func deleteAlbum(albumId: String) async throws {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
    }
    
    func saveLog(request: AlbumLogRequest) async throws -> AlbumLog {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        return AlbumLog.mock
    }
}
#endif
