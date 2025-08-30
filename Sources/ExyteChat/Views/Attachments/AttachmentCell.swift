//
//  Created by Alex.M on 16.06.2022.
//

import SwiftUI

public struct AttachmentCell: View {

    @Environment(\.chatTheme) var theme

    let attachment: Attachment
    let size: CGSize
    let onTap: (Attachment) -> Void

    public init(attachment: Attachment, size: CGSize, onTap: @escaping (Attachment) -> Void) {
        self.attachment = attachment
        self.size = size
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if attachment.type == .image {
                content
            } else if attachment.type == .video {
                content
                    .overlay {
                        theme.images.message.playVideo
                            .resizable()
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
            } else {
                content
                    .overlay {
                        Text("Unknown", bundle: .module)
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                onTap(attachment)
            }
        )
    }

//    var content: some View {
//        AsyncImageView(url: attachment.thumbnail, size: size)
//    }
    
    @ViewBuilder
    var content: some View {
        if attachment.type == .image {
            AsyncImage(url: attachment.thumbnail) { phase in
                switch phase {
                case .empty:
                    // Placeholder while loading
                    MediaPlaceholderView(size: size)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                case .failure(_):
                    // Fallback image on failure
                    MediaPlaceholderView(size: size)
                        
                @unknown default:
                    EmptyView()
                }
            }
        } else if attachment.type == .video {
            VideoThumbnailView(url: attachment.thumbnail, size: size)
        } else {
            Rectangle()
                .foregroundColor(.gray)
                .frame(width: size.width, height: size.height)
        }
    }

    
}

struct AsyncImageView: View {

    @Environment(\.chatTheme) var theme

    let attachment: Attachment
    let size: CGSize

    var body: some View {
        CachedAsyncImage(
            url: attachment.thumbnail,
            cacheKey: attachment.thumbnailCacheKey
        ) { imageView in
            imageView
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } placeholder: {
            ZStack {
                Rectangle()
                    .foregroundColor(theme.colors.inputBG)
                    .frame(width: size.width, height: size.height)
                ActivityIndicator(size: 30, showBackground: false)
            }
        }
    }
}


import AVFoundation

struct VideoThumbnailView: View {
    let url: URL
    let size: CGSize

    @State private var thumbnailImage: UIImage?

    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Rectangle()
                    .foregroundColor(.gray)
                    .frame(width: size.width, height: size.height)
                    .onAppear {
                        generateThumbnail()
                    }
            }
        }
    }

    private func generateThumbnail() {
        Task {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                thumbnailImage = UIImage(cgImage: cgImage)
            } catch {
                print("Failed to generate thumbnail: \(error)")
            }
        }
    }
}


struct MediaPlaceholderView: View {
    var size: CGSize

    var body: some View {
        ZStack {
            // Background gradient or blur-style color
            LinearGradient(
                gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)
            .cornerRadius(12)
            .clipped()

            // Placeholder image/icon (centered)
            Image(systemName: "photo") // Use your asset or system icon
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 0.3, height: size.height * 0.3)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
