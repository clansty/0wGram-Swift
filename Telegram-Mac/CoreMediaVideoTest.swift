//
//  CoreMediaVideoTest.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.06.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    // entries
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init(""), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return SoftwareGradientBackgroundItem(initialSize, stableId)
    }))
    sectionId += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func CoreMediaVideoIOTest(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    


    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
//    capturer.start()
    

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    let stickers:Signal<[TelegramMediaFile], NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 2000)
        |> take(1)
        |> map { view in
            return view.entries.compactMap {
                $0.item as? StickerPackItem
            }.filter {
                $0.file.isAnimatedSticker
            }.map {
                $0.file
            }
        }

    _ = stickers.start(next: { files in
        
        try? FileManager.default.removeItem(atPath: "/Users/mike/downloads/tgs")
        try? FileManager.default.createDirectory(atPath: "/Users/mike/downloads/tgs", withIntermediateDirectories: true, attributes: nil)

        var signals:[Signal<String?, NoError>] = []
        for file in files {
            signals.append(context.account.postbox.mediaBox.resourceData(file.resource)
                |> filter { $0.complete }
                |> map { $0.complete ? $0.path : nil })
            
            _ = freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: file)).start()
        }
        
        let paths = combineLatest(signals)
            |> map { $0.compactMap { $0 } }
        
        var cached:Set<String> = Set()
        
        
        _ = paths.start(next: { paths in
            for path in paths {
                if !cached.contains(path) {
                    let output = "/Users/mike/downloads/tgs/\(arc4random())"
                    let data = try? Data(contentsOf: .init(fileURLWithPath: path), options: .mappedIfSafe)
                    if let data = data {
                        let unzip = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
                        try? unzip.write(to: .init(fileURLWithPath: output))
                        cached.insert(path)
                    }
                }
            }
        })
        
    })
    
    return modalController
}


/*
 
 */



