//
//  DebugLogger.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

func debugLog(_ message: String) {
#if DEBUG
    print(message)
#endif
}
