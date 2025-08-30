//
//  Created by Alex.M on 14.06.2022.
//

import SwiftUI

 

struct TextInputView: View {
    
    @Environment(\.chatTheme) private var theme
    @EnvironmentObject private var globalFocusState: GlobalFocusState
    
    @Binding var text: String
    @State var inputFieldId: UUID
    var style: InputViewStyle
    var availableInputs: [AvailableInputType]
    var localization: ChatLocalization
    
    /// ✅ Callback that sends true when user is typing, false when stopped
    var onTypingChanged: ((Bool) -> Void)? = nil
    var isGhostMode: Bool = false
    /// ✅ Internal state for managing typing detection
    @State private var isTyping: Bool = false
    @State private var lastTypingDate: Date = Date()
    
    var body: some View {
        TextField("", text: $text, prompt: Text(style == .message ? (isGhostMode ? localization.inputGhostPlaceholder : localization.inputPlaceholder) : localization.signatureText)
            .foregroundColor(style == .message ? theme.colors.inputPlaceholderText : theme.colors.inputSignaturePlaceholderText), axis: .vertical)
            .customFocus($globalFocusState.focus, equals: .uuid(inputFieldId))
            .foregroundColor(style == .message ? theme.colors.inputText : theme.colors.inputSignatureText)
            .padding(.vertical, 10)
            .padding(.leading, !isMediaGiphyAvailable() ? 12 : 0)
            .simultaneousGesture(
                TapGesture().onEnded {
                    globalFocusState.focus = .uuid(inputFieldId)
                }
            )
            .onChange(of: text) { _ in
                typingDetected()
            }
    }
    
    private func isMediaGiphyAvailable() -> Bool {
        return availableInputs.contains(.media) || availableInputs.contains(.giphy)
    }
    
    /// ✅ Called when text changes — detects typing and schedules stop check
    private func typingDetected() {
        let now = Date()
        lastTypingDate = now
        
        if !isTyping {
            isTyping = true
            onTypingChanged?(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let timeSinceLastType = Date().timeIntervalSince(lastTypingDate)
            if timeSinceLastType >= 1.5 && isTyping {
                isTyping = false
                onTypingChanged?(false)
            }
        }
    }
}
