//
//  Card.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

enum Direction {
    case right
    case left
}

let MAX_POSITION = 5
let MAX_X_MOVEMENT = 105.0

struct CardView: View {

    var moment: Moment
    var position: Int
    var positionFromEnd: Int
    var totalCount: Int
    var movable: Bool = false
    var removal: ((Direction) -> Void)? = nil
    
    @State private var opacity: CGFloat = 1.0
    @State private var offset = CGSize.zero
    
    var body: some View {
        VStack {
            AsyncImage(url: moment.img, content: { image in
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
            }, placeholder: {})
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text(moment.name)
                        .foregroundStyle(.black.opacity(0.7))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(moment.rarity + " - " + moment.edition)
                        .foregroundStyle(.black.opacity(0.7))
                        .font(.subheadline)
                    HStack {
                        Text(moment.team)
                            .font(.subheadline)
                        Text(moment.serial)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.black.opacity(0.5))
                    .fontWeight(.bold)
                }
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: 350, maxHeight: 400)
        .background(Color.mint.gradient)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.mint.opacity(0.5), lineWidth: 8)
        )
        .shadow(
            color: Color(
                .sRGBLinear,
                white: 0,
                opacity: isShownOnTop() ? 0.33 : 0.0
            ),
            radius: 10
        )
        .padding()
        .rotationEffect(.degrees(Double(offset.width / 5)))
        .offset(
            x: offset.width * 1.5,
            y: (
                CGFloat(isShownOnTop() ? position-positionFromEnd : 0) * 7
            ) + offset.height
        )
        .opacity(opacity)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if !movable {
                        return
                    }
                    
                    offset = gesture.translation
                    
                    if offset.width > MAX_X_MOVEMENT {
                        withAnimation {
                            opacity = 0.75
                        }
                    }
                    else if offset.width < -MAX_X_MOVEMENT {
                        withAnimation {
                            opacity = 0.75
                        }
                    } else {
                        withAnimation {
                            opacity = 1.0
                        }
                    }
                }
                .onEnded { _ in
                    if !movable {
                        return
                    }
                    
                    if offset.width > MAX_X_MOVEMENT {
                        withAnimation {
                            offset.width = 1000
                        }
                        removal?(.right)
                    }
                    else if offset.width < -MAX_X_MOVEMENT {
                        withAnimation {
                            offset.width = -1000
                        }
                        removal?(.left)
                    } else {
                        withAnimation(Animation.interpolatingSpring(stiffness: 160, damping: 14)) {
                            offset = .zero
                        }
                    }
                }
        )
    }
    
    func isShownOnTop() -> Bool {
        return self.positionFromEnd <= MAX_POSITION || self.totalCount <= MAX_POSITION
    }
}

struct Card_Previews: PreviewProvider {
    static var previews: some View {
        CardView(moment: testMoments[0], position: 5, positionFromEnd: 0, totalCount: 0) { direction in
            print("REMOVED", direction)
        }
    }
}
