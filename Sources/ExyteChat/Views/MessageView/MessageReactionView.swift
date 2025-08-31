//
//  MessageView+Reaction.swift
//  Chat
//

import SwiftUI

extension MessageView {
    
    @ViewBuilder
    func reactionsView(_ message: Message, maxReactions: Int = 5, reactionDelegate: ReactionDelegate?) -> some View {
        let preparedReactions = prepareReactions(message: message, maxReactions: maxReactions)
        let overflowBubbleText = "+\(message.reactions.count - maxReactions + 1)"
        
        HStack(spacing: -bubbleSize.width / 5) {
            if !message.user.isCurrentUser {
                overflowBubbleView(
                    leadingSpacer: true,
                    needsOverflowBubble: preparedReactions.needsOverflowBubble,
                    text: overflowBubbleText,
                    containsReactionFromCurrentUser: preparedReactions.overflowContainsCurrentUser,
                    message: message,
                    reactionDelegate: reactionDelegate
                )
            }
            
            ForEach(Array(preparedReactions.reactions.enumerated()), id: \.element) { index, reaction in
                ReactionBubble(reaction: reaction, font: Font(font))
                    .transition(.scaleAndFade)
                    .zIndex(message.user.isCurrentUser ? Double(preparedReactions.reactions.count - index) : Double(index + 1))
                    .sizeGetter($bubbleSize)
                    .onTapGesture {
                        // Always show reaction overview when any reaction is tapped
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowReactionOverview"),
                            object: nil,
                            userInfo: ["message": message]
                        )
                        
                        // If this is the current user's reaction, also remove it by sending the same reaction type
                        if reaction.user.isCurrentUser, let reactionDelegate = reactionDelegate {
                            let draftReaction = DraftReaction(messageID: message.id, type: reaction.type)
                            reactionDelegate.didReact(to: message, reaction: draftReaction)
                        }
                    }
            }
            
            if message.user.isCurrentUser {
                overflowBubbleView(
                    leadingSpacer: false,
                    needsOverflowBubble: preparedReactions.needsOverflowBubble,
                    text: overflowBubbleText,
                    containsReactionFromCurrentUser: preparedReactions.overflowContainsCurrentUser,
                    message: message,
                    reactionDelegate: reactionDelegate
                )
            }
        }
    }
    
    @ViewBuilder
    func overflowBubbleView(leadingSpacer:Bool, needsOverflowBubble:Bool, text:String, containsReactionFromCurrentUser:Bool, message: Message, reactionDelegate: ReactionDelegate?) -> some View {
        if needsOverflowBubble {
            ReactionBubble(
                reaction: .init(
                    user: .init(
                        id: "null",
                        name: "",
                        avatarURL: nil,
                        isCurrentUser: containsReactionFromCurrentUser
                    ),
                    type: .emoji(text),
                    status: .sent
                ),
                font: .footnote.weight(.light)
            )
            .padding(message.user.isCurrentUser ? .trailing : .leading, -3)
            .onTapGesture {
                // Show reaction overview when overflow bubble is tapped
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowReactionOverview"),
                    object: nil,
                    userInfo: ["message": message]
                )
            }
        }
    }
    
    struct PreparedReactions {
        /// Sorted Reactions by most recent -> oldest (trimmed to maxReactions)
        let reactions:[Reaction]
        /// Indicates whether we need to add an overflow bubble (due to the number of Reactions exceeding maxReactions)
        let needsOverflowBubble:Bool
        /// Indicates whether the clipped reactions (oldest reactions beyond maxReaction) contain a reaction from the current user
        /// - Note: This value is used to color the background of the overflow bubble
        let overflowContainsCurrentUser:Bool
    }
    
    /// Orders the reactions by most recent to oldest, reverses their layout based on alignment and determines if an overflow bubble is necessary
    private func prepareReactions(message:Message, maxReactions:Int) -> PreparedReactions {
        guard maxReactions > 1, !message.reactions.isEmpty else {
            return .init(reactions: [], needsOverflowBubble: false, overflowContainsCurrentUser: false)
        }
        // If we have more reactions than maxReactions, then we'll need an overflow bubble
        let needsOverflowBubble = message.reactions.count > maxReactions
        // Sort all reactions by most recent -> oldest
        var reactions = Array(message.reactions.sorted(by: { $0.createdAt > $1.createdAt }))
        // Check if our current user has a reaction in the overflow reactions (used for coloring the overflow bubble)
        var overflowContainsCurrentUser: Bool = false
        if needsOverflowBubble {
           overflowContainsCurrentUser = reactions[min(reactions.count, maxReactions)...].contains(where: {  $0.user.isCurrentUser })
        }
        // Trim the reactions array if necessary
        if needsOverflowBubble { reactions = Array(reactions.prefix(maxReactions - 1)) }
        
        return .init(
            reactions: message.user.isCurrentUser ? reactions : reactions.reversed(),
            needsOverflowBubble: needsOverflowBubble,
            overflowContainsCurrentUser: overflowContainsCurrentUser
        )
    }
}

struct ReactionBubble: View {
    
    @Environment(\.chatTheme) var theme
    
    let reaction: Reaction
    let font: Font
    
    @State private var phase = 0.0
    
    var fillColor: Color {
        switch reaction.status {
        case .sending, .sent, .read:
            // Use the same color for both current user and other users
            return theme.colors.messageFriendBG
        case .error:
            return .red
        }
    }
    
    var opacity: Double {
        switch reaction.status {
        case .sent, .read:
            return 1.0
        case .sending, .error:
            return 0.7
        }
    }
    
    var body: some View {
        Text(reaction.emoji ?? "?")
            .font(.system(size: 14)) // Slightly larger than before but still compact
            .opacity(opacity)
            .foregroundStyle(theme.colors.messageText(reaction.user.type))
            .padding(4) // Reduced padding from 6 to 4
            .background(
                ZStack {
                    Circle()
                        .fill(fillColor)
                    // Only show stroke animation when sending
                    if reaction.status == .sending {
                        Circle()
                            .stroke(style: .init(lineWidth: 2, lineCap: .round, dash: [100, 50], dashPhase: phase))
                            .fill(theme.colors.messageFriendBG)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                                    phase -= 150
                                }
                            }
                    }
                }
            )
    }
}
