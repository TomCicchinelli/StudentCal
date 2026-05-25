//
//  Keyboarddismiss.swift
//  StudyPlanner
//
//  Created by Cicchinelli Tommaso on 22/05/2026.
//

//
//  KeyboardDismiss.swift
//  StudyPlanner
//
//  Apply .dismissKeyboardOnTap() to any view to make tapping
//  outside a text field close the keyboard.
//

import SwiftUI

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}
