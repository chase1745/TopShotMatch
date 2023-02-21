//
//  MomentListDetailView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

struct MomentListDetailView: View {
    var moment: Moment
    
    var body: some View {
        HStack {
            AsyncImage(url: moment.img, content: { image in
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 60)
            }, placeholder: {})
            
            VStack(alignment: .leading) {
                HStack {
                    Text(moment.name)
                    Text("-")
                    Text(moment.rarity)
                }
                HStack {
                    Text(moment.serial)
                    Text("-")
                    Text(moment.edition)
                }.font(.footnote)
            }
        }
    }
}

struct MomentListDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MomentListDetailView(moment: testMoments[0])
    }
}
