//
//  MessageStatusViewNew.swift
//  Chat
//
//  Created by Rajneesh Prakash on 21/06/25.
//
import SwiftUI


struct StatusText: View {
    
    var text: String
    var color: Color?
    
    var body: some View {
        VStack(alignment: .trailing){
            
            Text(text)
                .font(.caption2)
                .foregroundColor((color != nil) ? color : Color.gray)
        }
        .frame(width: 100,height: 20)
            .padding(.trailing,4)
    
    }
}

struct MessageStatusViewNew: View {

    @Environment(\.chatTheme) private var theme

    let status: Message.Status
    let onRetry: () -> Void

    var body: some View {
        Group {
            switch status {
            case .sending:
                StatusText(text:"...",color: theme.colors.mainText)
            case .sent:
               StatusText(text:"Sent",color: theme.colors.mainText)
            case .read:
                StatusText(text:"Seen",color: theme.colors.mainText)
            case .error:
                Button {
                    onRetry()
                } label: {
                    getTheme().images.message.error
                        .resizable()
                }
                .foregroundColor(theme.colors.statusError)
            }
        }
        .onAppear{
            debugPrint("MessageStatusViewNew --------",status)
        }
        .viewSize(MessageView.statusViewSize)
        .padding(.trailing, MessageView.horizontalStatusPadding)
    }

    @MainActor
        private func getTheme() -> ChatTheme {
            return theme
        }
}
