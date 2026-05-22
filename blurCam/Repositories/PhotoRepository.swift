import Foundation
import Photos
import UIKit

/// Error types for photo repository operations
enum PhotoRepositoryError: LocalizedError {
    case saveFailed(String)
    case invalidImageData
    case videoSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "写真の保存に失敗しました: \(message)"
        case .invalidImageData:
            return "無効な画像データです"
        case .videoSaveFailed(let message):
            return "動画の保存に失敗しました: \(message)"
        }
    }
}

/// Concrete implementation of PhotoRepositoryProtocol using PHPhotoLibrary
final class PhotoRepository: PhotoRepositoryProtocol {

    func savePhoto(_ imageData: Data) async throws {
        guard UIImage(data: imageData) != nil else {
            throw PhotoRepositoryError.invalidImageData
        }

        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
        }
    }

    func saveVideo(_ videoURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw PhotoRepositoryError.videoSaveFailed("動画ファイルが見つかりません")
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }

    func fetchLatestMedia() async -> MediaItem? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        guard let asset = fetchResult.firstObject else {
            return nil
        }

        let thumbnail = await fetchThumbnail(for: asset)
        let mediaType: MediaItem.MediaType = asset.mediaType == .video ? .video : .photo

        return MediaItem(
            id: asset.localIdentifier,
            mediaType: mediaType,
            thumbnail: thumbnail,
            videoURL: nil,
            fullImage: nil
        )
    }

    func fetchFullImage(for identifier: String) async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func fetchVideoURL(for identifier: String) async -> URL? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject, asset.mediaType == .video else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic

            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func fetchThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .fast

            let targetSize = CGSize(width: 200, height: 200)

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Only resume on the final image (not degraded placeholder)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
