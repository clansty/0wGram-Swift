//
//  GroupCallParticipantRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import SyncCore
import Postbox
import TelegramCore

private let photoSize: NSSize = NSMakeSize(35, 35)

private let fakeIcon = generateFakeIconReversed(foregroundColor: GroupCallTheme.customTheme.redColor, backgroundColor: GroupCallTheme.customTheme.backgroundColor)
private let scamIcon = generateScamIconReversed(foregroundColor: GroupCallTheme.customTheme.redColor, backgroundColor: GroupCallTheme.customTheme.backgroundColor)
private let verifyIcon = NSImage(named: "Icon_VerifyDialog")!.precomposed(GroupCallTheme.customTheme.accentColor)

final class GroupCallParticipantRowItem : GeneralRowItem {
    fileprivate let data: PeerGroupCallData
    private let _contextMenu: ()->Signal<[ContextMenuItem], NoError>
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let isLastItem: Bool
    fileprivate let isInvited: Bool
    fileprivate let drawLine: Bool
    fileprivate let invite:(PeerId)->Void
    fileprivate let canManageCall:Bool
    fileprivate let takeVideo:()->NSView?
    fileprivate let volume: TextViewLayout?
    fileprivate let audioLevel:(PeerId)->Signal<Float?, NoError>?
    fileprivate private(set) var buttonImage: (CGImage, CGImage?)? = nil
    
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, data: PeerGroupCallData, canManageCall: Bool, isInvited: Bool, isLastItem: Bool, drawLine: Bool, viewType: GeneralViewType, action: @escaping()->Void, invite:@escaping(PeerId)->Void, contextMenu:@escaping()->Signal<[ContextMenuItem], NoError>, takeVideo:@escaping()->NSView?, audioLevel:@escaping(PeerId)->Signal<Float?, NoError>?) {
        self.data = data
        self.audioLevel = audioLevel
        self.account = account
        self.canManageCall = canManageCall
        self.invite = invite
        self._contextMenu = contextMenu
        self.isInvited = isInvited
        self.drawLine = drawLine
        self.takeVideo = takeVideo
        self.titleLayout = TextViewLayout(.initialize(string: data.peer.displayTitle, color: (data.state != nil ? .white : GroupCallTheme.grayStatusColor), font: .medium(.text)), maximumNumberOfLines: 1)
        self.isLastItem = isLastItem
        var string:String = L10n.peerStatusRecently
        var color:NSColor = GroupCallTheme.grayStatusColor
        if let state = data.state {
            if data.wantsToSpeak, let _ = state.muteState {
                string = L10n.voiceChatStatusWantsSpeak
                color = GroupCallTheme.blueStatusColor
            } else if let muteState = state.muteState, muteState.mutedByYou {
                string = muteState.mutedByYou ? L10n.voiceChatStatusMutedForYou : L10n.voiceChatStatusMuted
                color = GroupCallTheme.speakLockedColor
            } else if data.isSpeaking {
                string = L10n.voiceChatStatusSpeaking
                color = GroupCallTheme.greenStatusColor
            } else {
                if let about = data.about {
                    string = about
                    color = GroupCallTheme.grayStatusColor
                } else {
                    string = L10n.voiceChatStatusListening
                    color = GroupCallTheme.grayStatusColor
                }
            }
        } else if data.peer.id == data.accountPeerId {
            if let about = data.about {
                string = about
                color = GroupCallTheme.grayStatusColor.withAlphaComponent(0.6)
            } else {
                string = L10n.voiceChatStatusConnecting.lowercased()
                color = GroupCallTheme.grayStatusColor.withAlphaComponent(0.6)
            }
        } else if isInvited {
            string = L10n.voiceChatStatusInvited
        }
        if let volume = data.unsyncVolume ?? data.state?.volume, volume != 10000 {
            if let muteState = data.state?.muteState, !muteState.canUnmute || muteState.mutedByYou {
                self.volume = nil
            } else {
                var volumeColor: NSColor
                if volume == 0 {
                    volumeColor = GroupCallTheme.grayStatusColor
                } else {
                    volumeColor = color
                }
                self.volume = TextViewLayout(.initialize(string: "\(Int(Float(volume) / 10000 * 100))%", color: volumeColor, font: .normal(.short)))
            }
        } else {
            self.volume = nil
        }
        

        
        self.statusLayout = TextViewLayout(.initialize(string: string, color: color, font: .normal(.short)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 48, stableId: stableId, type: .none, viewType: viewType, action: action, inset: NSEdgeInsetsMake(0, 0, 0, 0), enabled: true)
        
        
        if isActivePeer {
            if data.isSpeaking {
                self.buttonImage = (GroupCallTheme.small_speaking, GroupCallTheme.small_speaking_active)
            } else {
                if let muteState = data.state?.muteState {
                    if !muteState.canUnmute && data.isRaisedHand {
                        self.buttonImage = (GroupCallTheme.small_raised_hand, GroupCallTheme.small_raised_hand_active)
                    } else if muteState.canUnmute && !muteState.mutedByYou {
                        buttonImage = (GroupCallTheme.small_muted, GroupCallTheme.small_muted_active)
                    } else {
                        buttonImage = (GroupCallTheme.small_muted_locked, GroupCallTheme.small_muted_locked_active)
                    }
                } else if data.state == nil {
                    buttonImage = (GroupCallTheme.small_muted, GroupCallTheme.small_muted_active)
                } else {
                    buttonImage = (GroupCallTheme.small_unmuted, GroupCallTheme.small_unmuted_active)
                }
            }
        } else {
            if isInvited {
                buttonImage = (GroupCallTheme.invitedIcon, nil)
            } else {
                buttonImage = (GroupCallTheme.inviteIcon, nil)
            }
        }

    }
    
    var itemInset: NSEdgeInsets {
        return NSEdgeInsetsMake(0, 12, 0, 12)
    }
    
    var isActivePeer: Bool {
        return data.state != nil || data.peer.id == data.accountPeerId
    }
    
    var peer: Peer {
        return data.peer
    }
    
    
    var supplementIcon: (CGImage, NSSize)? {
        
        let isScam: Bool = peer.isScam
        let isFake: Bool = peer.isFake
        let verified: Bool = peer.isVerified
        
        

        if isScam {
            return (scamIcon, .zero)
        } else if isFake {
            return (fakeIcon, .zero)
        } else if verified {
            return (verifyIcon, NSMakeSize(-4, -4))
        } else {
            return nil
        }
    }
    
    override var hasBorder: Bool {
        return false
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.volume?.measure(width: .greatestFiniteMagnitude)
        let inset: CGFloat
        if let volume = self.volume {
            inset = volume.layoutSize.width + 28
        } else {
            inset = 0
        }
        
                
        titleLayout.measure(width: width - 40 - itemInset.left - itemInset.left - itemInset.right - 24 - itemInset.right)
        statusLayout.measure(width: width - 40 - itemInset.left - itemInset.left - itemInset.right - 24 - itemInset.right - inset)
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return _contextMenu()
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallParticipantRowView.self
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}


private final class GroupCallParticipantRowView : GeneralContainableRowView {
    private let photoView: AvatarControl = AvatarControl(font: .avatar(25))
    private let titleView: TextView = TextView()
    private var statusView: TextView?
    private let micro = VoiceChatMicrophoneView()
    private let button = ImageButton()
    private let separator: View = View()
    private let playbackAudioLevelView: VoiceBlobView
    private var scaleAnimator: DisplayLinkAnimator?
    private let videoContainer: View = View()
    private var volumeView: TextView?
    private var statusImageView: ImageView?
    private var supplementImageView: ImageView?
    private let audioLevelDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        playbackAudioLevelView = VoiceBlobView(
            frame: NSMakeRect(0, 0, 55, 55),
            maxLevel: 0.3,
            smallBlobRange: (0, 0),
            mediumBlobRange: (0.7, 0.8),
            bigBlobRange: (0.8, 0.9)
        )

        super.init(frame: frameRect)
        photoView.setFrameSize(photoSize)
        addSubview(playbackAudioLevelView)
        addSubview(photoView)
        addSubview(titleView)
        addSubview(separator)
        addSubview(button)
        button.addSubview(micro)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false

                
        photoView.addSubview(videoContainer)
        videoContainer.frame = .init(origin: .zero, size: photoSize)
        photoView.layer?.cornerRadius = photoSize.height / 2
        
        button.animates = true

        button.autohighlight = true
        button.set(handler: { [weak self] _ in
            guard let item = self?.item as? GroupCallParticipantRowItem else {
                return
            }
            if item.data.state == nil {
                item.invite(item.peer.id)
            } else {
                _ = item.menuItems(in: .zero).start(next: { [weak self] items in
                    if let event = NSApp.currentEvent, let button = self?.button {
                        let menu = NSMenu()
                        menu.appearance = darkPalette.appearance
                        menu.items = items
                        NSMenu.popUpContextMenu(menu, with: event, for: button)
                    }
                })
            }
        }, for: .SingleClick)
        
        containerView.set(handler: { [weak self] _ in
            if let event = NSApp.currentEvent {
                self?.showContextMenu(event)
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        
        let frame = containerView.frame
        
        self.photoView.centerY(x: item.itemInset.left)

        titleView.setFrameOrigin(NSMakePoint(item.itemInset.left + photoSize.width + item.itemInset.left, 6))
        
        if let imageView = self.supplementImageView {
            imageView.setFrameOrigin(NSMakePoint(titleView.frame.maxX + 3 + (item.supplementIcon?.1.width ?? 0), titleView.frame.minY + (item.supplementIcon?.1.height ?? 0)))
        }
        
        statusView?.setFrameOrigin(statusViewPoint)
        volumeView?.setFrameOrigin(volumeViewPoint)
        statusImageView?.setFrameOrigin(statusImageViewViewPoint)
        
        if item.drawLine {
            separator.frame = NSMakeRect(titleView.frame.minX, frame.height - .borderSize, frame.width - titleView.frame.minX, .borderSize)
        } else {
            separator.frame = .zero
        }

        button.centerY(x: frame.width - 12 - button.frame.width)

        playbackAudioLevelView.centerY(x: 2, addition: 1)
    }
    
    override func updateColors() {
        super.updateColors()
        self.titleView.backgroundColor = backdorColor
        self.statusView?.backgroundColor = backdorColor
        self.separator.backgroundColor = GroupCallTheme.memberSeparatorColor
    }
    
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previousItem = self.item as? GroupCallParticipantRowItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallParticipantRowItem else {
            return
        }
        
        let videoView = item.takeVideo()
        
        if let videoView = videoView {
            let previous = self.videoContainer.subviews.first
            var isPresented: Bool = false
            if previous != videoView, let previous = previous {
                if animated {
                    previous.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] _ in
                        previous?.removeFromSuperview()
                    })
                } else {
                    previous.removeFromSuperview()
                }
                isPresented = true
            }
            videoView.frame = self.videoContainer.bounds
            self.videoContainer.addSubview(videoView)
            
            if animated && isPresented {
                videoView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        } else {
            if let first = self.videoContainer.subviews.first {
                if animated {
                    first.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak first] _ in
                        first?.removeFromSuperview()
                    })
                } else {
                    first.removeFromSuperview()
                }
            }
        }
        
        if let icon = item.supplementIcon {
            let current: ImageView
            if let value = self.supplementImageView {
                current = value
            } else {
                current = ImageView()
                self.supplementImageView = current
                addSubview(current)
            }
            current.image = icon.0
            current.sizeToFit()
        } else {
            self.supplementImageView?.removeFromSuperview()
            self.supplementImageView = nil
        }
        if item.isActivePeer {
            button.userInteractionEnabled = item.canManageCall
        } else {
            if item.isInvited {
                button.userInteractionEnabled = false
            } else {
                button.userInteractionEnabled = true
            }
        }
        
        if previousItem?.buttonImage?.0 != item.buttonImage?.0 {
            if let image = item.buttonImage {
                button.set(image: image.0, for: .Normal)
                if let highlight = image.1 {
                    button.set(image: highlight, for: .Highlight)
                } else {
                    button.removeImage(for: .Highlight)
                }
            }
            button.sizeToFit(.zero, NSMakeSize(28, 28), thatFit: true)
        }
        
        if item.data.accountPeerId == item.data.peer.id {
            button.userInteractionEnabled = false
        }

        if let audioLevel = item.audioLevel(item.data.peer.id) {
            self.audioLevelDisposable.set(audioLevel.start(next: { [weak item, weak self] value in
                if let item = item {
                    self?.updateAudioLevel(value, item: item, animated: animated)
                }
            }))
        } else {
            self.audioLevelDisposable.set(nil)
            self.updateAudioLevel(nil, item: item, animated: animated)
        }

        

        let activityColor: NSColor
        if  let muteState = item.data.state?.muteState, muteState.mutedByYou {
            activityColor = GroupCallTheme.speakLockedColor
        } else {
            activityColor = item.data.isSpeaking ? GroupCallTheme.speakActiveColor : GroupCallTheme.speakInactiveColor
        }

        playbackAudioLevelView.setColor(activityColor)


        
        titleView.update(item.titleLayout)
        photoView.setPeer(account: item.account, peer: item.peer, message: nil, size: NSMakeSize(floor(photoSize.width * 1.5), floor(photoSize.height * 1.5)))
        photoView._change(opacity: item.isActivePeer ? 1.0 : 0.5, animated: animated)


        if videoView != nil || item.volume != nil, let state = item.data.state {
            var statusImage: CGImage
            if videoView != nil {
                if let muteState = state.muteState, muteState.mutedByYou {
                    statusImage = GroupCallTheme.status_video_red
                } else {
                    if item.data.isSpeaking {
                        statusImage = GroupCallTheme.status_video_green
                    } else {
                        statusImage = GroupCallTheme.status_video_accent
                    }
                }
            } else {
                if let muteState = state.muteState, muteState.mutedByYou {
                    statusImage = GroupCallTheme.status_muted
                } else {
                    if item.data.isSpeaking {
                        statusImage = GroupCallTheme.status_unmuted_green
                    } else if item.data.wantsToSpeak {
                        statusImage = GroupCallTheme.status_unmuted_accent
                    } else {
                        statusImage = GroupCallTheme.status_unmuted_gray
                    }
                }
            }
            var isPresented = false
            if statusImageView == nil {
                statusImageView = ImageView()
                addSubview(statusImageView!)
                isPresented = true
            }
            guard let statusImageView = statusImageView else {
                return
            }
            if statusImageView.image != statusImage {
                statusImageView.image = statusImage
                statusImageView.sizeToFit()
                statusImageView.setFrameOrigin(statusImageViewViewPoint)
            }
        } else {
            if let statusImageView = self.statusImageView {
                self.statusImageView = nil
                if animated {
                    statusImageView.layer?.animateAlpha(from: 1, to: 0, duration: 0.3, removeOnCompletion: false, completion: { [weak statusImageView] _ in
                        statusImageView?.removeFromSuperview()
                    })
                } else {
                    statusImageView.removeFromSuperview()
                }
                
            }
        }
        
        if statusView?.layout?.attributedString.string != item.statusLayout.attributedString.string {
            if let statusView = statusView {
                if animated {
                    statusView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak statusView] _ in
                        statusView?.removeFromSuperview()
                    })
                    statusView.layer?.animatePosition(from: statusView.frame.origin, to: NSMakePoint(statusView.frame.minX, statusView.frame.minY + 10))
                } else {
                    statusView.removeFromSuperview()
                }
            }
            
            let animated = statusView?.layout != nil
            
            let statusView = TextView()
            self.statusView = statusView
            statusView.userInteractionEnabled = false
            statusView.isSelectable = false
            statusView.update(item.statusLayout)
            addSubview(statusView)
            statusView.setFrameOrigin(statusViewPoint)
            
            if animated {
                statusView.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                statusView.layer?.animatePosition(from: NSMakePoint(statusViewPoint.x, statusViewPoint.y - 10), to: statusViewPoint)
            }
        }
        
        statusView?.update(item.statusLayout)
        
        
        
        
        if let volume = item.volume {
            var isPresented: Bool = false
            if volumeView == nil {
                self.volumeView = TextView()
                self.volumeView?.userInteractionEnabled = false
                self.volumeView?.isSelectable = false
                addSubview(volumeView!)
                isPresented = true
            }
            guard let volumeView = volumeView else {
                return
            }
            volumeView.update(volume)

            if isPresented {
                volumeView.setFrameOrigin(volumeViewPoint)
            }
            if isPresented && animated {
                volumeView.layer?.animateAlpha(from: 0, to: 1, duration: 0.3)
                volumeView.layer?.animatePosition(from: NSMakePoint(volumeView.frame.minX - volumeView.frame.width, volumeView.frame.minY), to: volumeView.frame.origin)
                
                if let statusView = statusView {
                    statusView.change(pos: statusViewPoint, animated: animated)
                }
            }
        } else {
            if let volumeView = volumeView {
                self.volumeView = nil
                if animated {
                    volumeView.layer?.animateAlpha(from: 1, to: 0, duration: 0.3, removeOnCompletion: false, completion: { [weak volumeView] _ in
                        volumeView?.removeFromSuperview()
                    })
                    volumeView.layer?.animatePosition(from: volumeView.frame.origin, to: NSMakePoint(volumeView.frame.minX - volumeView.frame.width, volumeView.frame.minY))
                } else {
                    volumeView.removeFromSuperview()
                }
                if let statusView = statusView {
                    statusView.change(pos: statusViewPoint, animated: animated)
                }
            }
        }
    }
    
    private func updateAudioLevel(_ value: Float?, item: GroupCallParticipantRowItem, animated: Bool) {
        if (value != nil || item.data.isSpeaking)  {
            playbackAudioLevelView.startAnimating()
        } else {
            playbackAudioLevelView.stopAnimating()
        }
        playbackAudioLevelView.change(opacity: (value != nil || item.data.isSpeaking) ? 1 : 0, animated: animated)

        playbackAudioLevelView.updateLevel(CGFloat(value ?? 0))

        
        let audioLevel = value ?? 0
        let level = min(1.0, max(0.0, CGFloat(audioLevel)))
        let avatarScale: CGFloat
        if audioLevel > 0.0 {
            avatarScale = 0.9 + level * 0.07
        } else {
            avatarScale = 1.0
        }

        let value = CGFloat(truncate(double: Double(avatarScale), places: 2))

        let t = photoView.layer!.transform
        let scale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))

        if animated {
            self.scaleAnimator = DisplayLinkAnimator(duration: 0.1, from: scale, to: value, update: { [weak self] value in
                guard let `self` = self else {
                    return
                }
                let rect = self.photoView.bounds
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, rect.width / 2, 0)
                fr = CATransform3DScale(fr, value, value, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
                self.photoView.layer?.transform = fr
            }, completion: {

            })
        } else {
            self.scaleAnimator = nil
            self.photoView.layer?.transform = CATransform3DIdentity
        }
    }
    
    var statusViewPoint: NSPoint {
        guard let item = item as? GroupCallParticipantRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        
        if let statusView = statusView {
            point = NSMakePoint(item.itemInset.left + photoSize.width + item.itemInset.left, frame.height - statusView.frame.height - 6)
        }
        if let volume = item.volume {
            point.x += volume.layoutSize.width + 3
        }
        if let statusImageView = statusImageView {
            point.x += statusImageView.frame.width + 3
        }
        
        return point
    }
    var volumeViewPoint: NSPoint {
        guard let item = item as? GroupCallParticipantRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        
        if let volumeView = volumeView {
            point = NSMakePoint(item.itemInset.left + photoSize.width + item.itemInset.left, frame.height - volumeView.frame.height - 6)
        }
        if let statusImageView = statusImageView {
            point.x += statusImageView.frame.width + 3
        }
        return point
    }
    
    var statusImageViewViewPoint: NSPoint {
        guard let item = item as? GroupCallParticipantRowItem else {
            return .zero
        }
        var point: NSPoint = .zero
        
        if let statusImageView = statusImageView {
            point = NSMakePoint(item.itemInset.left + photoSize.width + item.itemInset.left, frame.height - statusImageView.frame.height - 6)
        }
        return point
    }

    deinit {
        audioLevelDisposable.dispose()
    }
    
    override var backdorColor: NSColor {
        return GroupCallTheme.membersColor
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        showContextMenu(event)
    }
    
    override var rowAppearance: NSAppearance? {
        return darkPalette.appearance
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
