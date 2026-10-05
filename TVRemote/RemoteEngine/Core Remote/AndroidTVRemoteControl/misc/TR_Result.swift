//
//  Result.swift
//  
//
//

import Foundation

public enum Result<T> {
    case Result(T)
    case Error(TR_AndroidTVRemoteControlError)
}
