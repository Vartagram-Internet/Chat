//
//  Created by Alex.M on 16.06.2022.
//

import SwiftUI

public struct AttachmentCell: View {

    @Environment(\.chatTheme) var theme

    let attachment: Attachment
    let size: CGSize
    let showCancel: Bool
    let onTap: (_ attachment: Attachment, _ isCancel: Bool) -> Void

    public init(
        attachment: Attachment, size: CGSize, showCancel: Bool = false,
        onTap: @escaping (_ attachment: Attachment, _ isCancel: Bool) -> Void
    ) {
        self.attachment = attachment
        self.size = size
        self.showCancel = showCancel
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if attachment.type == .image {
                ZStack {
                    content
                    if let status = attachment.fullUploadStatus {
                        switch status {
                        case .inProgress(.none):         // uploading status handled but not percent, simply show progress view
                            uploadingOverlay(percent: nil)
                        case .inProgress(let percent?):  // full upload status handling with percent, shows progress view with percent
                            uploadingOverlay(percent: percent)
                        case .complete:
                            EmptyView()
                        case .cancelled:
                            cancelledOverlay
                        case .error:
                            errorOverlay
                        }
                    } else {  // upload status not handled assumes that content is uploaded before being sent to receiver
                        EmptyView()
                    }
                }
            } else if attachment.type == .video {
                ZStack {
                    content
                    if let status = attachment.fullUploadStatus {
                        switch status {
                        case .inProgress(.none):
                            uploadingOverlay(percent: nil)
                        case .inProgress(let percent?):
                            uploadingOverlay(percent: percent)
                        case .complete:
                            VStack {
                                Spacer()
                                theme.images.message.playVideo
                                    .resizable()
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                Spacer()
                            }
                        case .cancelled:
                            cancelledOverlay
                        case .error:
                            errorOverlay
                        }
                    } else {
                        VStack {
                            Spacer()
                            theme.images.message.playVideo
                                .resizable()
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                            Spacer()
                        }
                    }
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
        .simultaneousGesture(attachmentTapGesture)
    }

    @ViewBuilder
    private func uploadingOverlay(percent: Int?) -> some View {
        Color.white.opacity(0.8)
        if showCancel {
            theme.images.message.cancel
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.4))
                .frame(width: 36, height: 36)
        }
        VStack {
            HStack {
                Spacer()
                if let percent {
                    AttachmentUploadStatusCapsuleView(percent)
                        .padding(4)
                } else {
                    AttachmentUploadStatusCapsuleView()
                        .padding(4)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var cancelledOverlay: some View {
        Color.white.opacity(0.8)
        VStack {
            HStack {
                Spacer()
                theme.images.message.cancel
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.4))
                    .frame(width: 26, height: 26)
                    .padding(4)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var errorOverlay: some View {
        Color.white.opacity(0.8)
        VStack {
            HStack {
                Spacer()
                theme.images.message.error
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.4))
                    .frame(width: 26, height: 26)
                    .padding(4)
            }
            Spacer()
        }
    }

    private var attachmentTapGesture: AnyGesture<Void>? {
        if let status = attachment.fullUploadStatus {
            switch status {
            case .cancelled: return nil
            case .error: return nil
            case .inProgress(_):
                if showCancel {
                    return AnyGesture(TapGesture().onEnded { onTap(attachment, true) })
                }
                else {
                    // only the sender can cancel an upload attachment
                    return nil
                }
            case .complete: return AnyGesture(TapGesture().onEnded { onTap(attachment, false) })
            }
        }

        // attachments are uploaded before displayed so show play button
        return AnyGesture(TapGesture().onEnded { onTap(attachment, false) })

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
