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
    func fetchAlbums(cursor: String?, limit: Int) async throws -> AlbumListPayload
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

// MARK: - AlbumService (실 구현체 stub)

/// API 스펙 확정 전 stub — 서버 스펙 확정 후 각 메서드 구현 예정
/// 이미지 업로드 방식(multipart vs presigned URL) 확정 필요
final class AlbumService: AlbumServiceProtocol {
    
    func fetchAlbums(cursor: String?, limit: Int) async throws -> AlbumListPayload {
        fatalError("TODO: 서버 스펙 확정 후 구현")
    }
    
    func createAlbum(request: AlbumCreateRequest) async throws -> AlbumCreateResponse {
        fatalError("TODO: 서버 스펙 확정 후 구현")
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
}

// MARK: - MockAlbumService (DEBUG 전용)

#if DEBUG
final class MockAlbumService: AlbumServiceProtocol {
    
    var simulatedError: AlbumError? = nil   // simulatedError: 에러 시나리오 테스트
    var isEmpty: Bool = false              // isEmpty: 빈 목록 테스트
    var delay: UInt64 = 500_000_000       // 응답 지연 시뮬레이션(0.5초)
    
    func fetchAlbums(cursor: String?, limit: Int) async throws -> AlbumListPayload {
        try await Task.sleep(nanoseconds: delay)
        if let error = simulatedError { throw error }
        if isEmpty { return AlbumListPayload(albums: [], totalCount: 0, hasNext: false) }
        return AlbumListPayload(
            albums: AlbumCard.mockItems,
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
