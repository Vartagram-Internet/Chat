//
//  AttachmentsEditorNew.swift
//  Chat
//
//  Created by Rajneesh Prakash on 20/06/25.
//
 

import SwiftUI
import ExyteMediaPicker
import ActivityIndicatorView
import Foundation
import PhotosUI
import UIKit

struct AttachmentsEditorNew<InputViewContent: View>: View {
    
    typealias InputViewBuilderClosure = ChatView<EmptyView, InputViewContent, DefaultMessageMenuAction>.InputViewBuilderClosure
    
    @Environment(\.chatTheme) var theme
    @Environment(\.mediaPickerTheme) var mediaPickerTheme
    @Environment(\.mediaPickerThemeIsOverridden) var mediaPickerThemeIsOverridden

    @EnvironmentObject private var keyboardState: KeyboardState
    @EnvironmentObject private var globalFocusState: GlobalFocusState

    @ObservedObject var inputViewModel: InputViewModel

    var inputViewBuilder: InputViewBuilderClosure?
    var chatTitle: String?
    var messageStyler: (String) -> AttributedString
    var orientationHandler: MediaPickerOrientationHandler
    var mediaPickerSelectionParameters: MediaPickerParameters?
    var availableInputs: [AvailableInputType]
    var localization: ChatLocalization

    @State private var seleсtedMedias: [Media] = []
    @State private var currentFullscreenMedia: Media?

    var showingAlbums: Bool {
        inputViewModel.mediaPickerMode == .albums
    }
    var showCamera: Bool  {
        inputViewModel.mediaPickerMode == .camera
    }
  //  @State private var isCameraLoaded: Bool = false
    
    var body: some View {
        
        ZStack {
            if(inputViewModel.mediaPickerMode == .camera){
                Color.black.ignoresSafeArea()
            }
            if(showCamera){
                CameraPicker { image in
              
                    if let image = image {
                        let mediaModel = CameraImageMedia(image: image)
                        let media = Media(source: mediaModel)

                        inputViewModel.attachments = InputViewAttachments(medias: [media])
                      

                    }


                }
                .onChange(of: inputViewModel.attachments.medias) { newValue in
                    if !newValue.isEmpty {
                      
                        inputViewModel.send()
                    }
                }

            }
            else{
                NativePhotoPicker { images in
                     let medias = images.map { image in
                         Media(source: CameraImageMedia(image: image)) // ✅ reuse your CameraImageMedia
                     }
                     inputViewModel.attachments.medias = medias
                     inputViewModel.send()
                 }
            }
          

            if inputViewModel.showActivityIndicator {
                ActivityIndicator()
            }
//            if(inputViewModel.mediaPickerMode == .camera && !isCameraLoaded){
//                VStack{
//                    Spacer().frame(height: 150).background(Color.black)
//                    ZStack {
//                        
//                            FakeCameraBlurBackground()
//
//                            Color.white.opacity(0.05) // Subtle white veil
//
//                            VisualEffectBlur(blurStyle: .light)
//                                .ignoresSafeArea()
//                       
//                      
//                    }.onAppear {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                            withAnimation{
//                                isCameraLoaded = true
//                            }
//                           
//                          }
//                    }
//                    CameraShutterArea()
//                }
//          
//                .ignoresSafeArea()
//           
//            }
        }
    }
 
}


 


struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var didFinishPicking: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
      
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"] // ✅ Allow both photo and video
        picker.videoQuality = .typeMedium                      // Optional: set video quality
        picker.cameraCaptureMode = .photo                    // You can toggle this dynamically

        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

 
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let mediaType = info[.mediaType] as? String {
                if mediaType == "public.image", let image = info[.originalImage] as? UIImage {
                    parent.didFinishPicking(image)
                } else if mediaType == "public.movie", let url = info[.mediaURL] as? URL {
                    // 👇 You can update your callback to pass the video URL or handle it separately
                 
                    // For now, just call didFinishPicking with nil or create a new callback
                    parent.didFinishPicking(nil)
                }
            }

            parent.presentationMode.wrappedValue.dismiss()
        }


        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.didFinishPicking(nil)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}



 

final class CameraImageMedia: MediaModelProtocol {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    var mediaType: MediaType? {
        .image
    }

    var duration: CGFloat? {
        nil
    }

    func getURL() async -> URL? {
        nil
    }

    func getThumbnailURL() async -> URL? {
        nil
    }

    func getData() async throws -> Data? {
        image.jpegData(compressionQuality: 0.9)
    }

    func getThumbnailData() async -> Data? {
        image.jpegData(compressionQuality: 0.3)
    }
}

 
struct NativePhotoPicker: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1 // or 1 for single image
        config.filter = .images // or .any for images + videos

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void

        init(onComplete: @escaping ([UIImage]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            let itemProviders = results.map(\.itemProvider)
            var images: [UIImage] = []
            let group = DispatchGroup()

            for provider in itemProviders {
                if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage {
                            images.append(image)
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.onComplete(images)
            }
        }
    }
}


 

struct FakeCameraBlurBackground: View {
    var body: some View {
      
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.75, green: 0.90, blue: 1.0),  // Sky blue
                    Color(red: 0.95, green: 0.85, blue: 0.70),  // Sand/beige
                    Color(red: 0.70, green: 0.80, blue: 0.65)   // Soft green
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
           
   
    }
}


  

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style = .light

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}


struct CameraShutterArea: View {
    var body: some View {
        ZStack {
            // Mock camera control area background
            Color.black.opacity(0.8)
                .ignoresSafeArea(edges: .bottom)

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    // White circular shutter button
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)

                        Circle()
                            .stroke(Color.gray.opacity(0.4), lineWidth: 4)
                            .frame(width: 78, height: 78)
                    }

                    Spacer()
                }
                .padding(.bottom, 40) // Padding from bottom safe area
            }
        }
        .frame(height: 150) // mimic camera bottom panel height
    }
}
