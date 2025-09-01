//
//  AudioCacheManager.swift
//  
//
//  Created by Assistant on Audio Fix.
//

import Foundation
@preconcurrency import AVFoundation

enum AudioCacheError: Error {
    case invalidURL
    case downloadFailed
    case fileNotFound
}

@MainActor
final class AudioCacheManager {
    static let shared = AudioCacheManager()
    
    private let cacheDirectory: URL
    private var downloadTasks: [URL: Task<URL?, Error>] = [:]
    
    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("AudioCache")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private static func getCacheDirectory() -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let audioCache = cacheDir.appendingPathComponent("AudioCache")
        try? FileManager.default.createDirectory(at: audioCache, withIntermediateDirectories: true)
        return audioCache
    }
    
    static func getLocalURL(for remoteURL: String) async throws -> URL {
        let cacheDir = getCacheDirectory()
        let fileName = remoteURL.components(separatedBy: "/").last ?? UUID().uuidString
        let localURL = cacheDir.appendingPathComponent(fileName)
        
        // Check if file already exists and validate it
        if FileManager.default.fileExists(atPath: localURL.path) {
            // Validate existing file
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                if fileSize > 0 {
                    print("Audio file already cached: \(localURL.path) (size: \(fileSize) bytes)")
                    return localURL
                } else {
                    print("Cached file is empty, re-downloading...")
                    try? FileManager.default.removeItem(at: localURL)
                }
            } catch {
                print("Error checking cached file, re-downloading: \(error)")
                try? FileManager.default.removeItem(at: localURL)
            }
        }
        
        // Download file using URLSessionDownloadTask for proper binary handling
        print("Downloading audio file from: \(remoteURL)")
        guard let url = URL(string: remoteURL) else {
            throw AudioCacheError.invalidURL
        }
        
        // Use download task instead of data task for better handling of binary files
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AudioCacheError.downloadFailed
        }
        
        // Move downloaded file to cache location
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        
        // Validate downloaded file
        let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        print("Audio file downloaded to: \(localURL.path) (size: \(fileSize) bytes)")
        
        // Additional validation - check if file has minimum size for audio
        if fileSize < 1024 { // Less than 1KB is suspicious for audio
            print("Warning: Downloaded file is very small (\(fileSize) bytes)")
        }
        
        // Test if the file is a valid audio file by trying to create an AVPlayerItem
        let testPlayerItem = AVPlayerItem(url: localURL)
        print("Audio file validation - created AVPlayerItem with status: \(testPlayerItem.status.rawValue)")
        
        return localURL
    }
}
