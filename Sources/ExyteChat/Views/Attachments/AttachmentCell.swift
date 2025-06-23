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
            AsyncImageView(url: attachment.thumbnail, size: size)
        } else if attachment.type == .video {
            VideoThumbnailView(url: attachment.thumbnail, size: size)
        } else {
            // Fallback UI for unknown types
            Rectangle()
                .foregroundColor(.gray)
                .frame(width: size.width, height: size.height)
        }
    }

    
}

struct AsyncImageView: View {

    @Environment(\.chatTheme) var theme

    let url: URL
    let size: CGSize

    var body: some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { imageView in
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


