//
//  History.swift
//  MC2
//
//  Created by Jefferson Mourent on 28/05/24.
//

import SwiftUI

struct History: View {
    var body: some View {
        NavigationView {
            VStack{
                List{
                    HStack{
                        Image("basketmerah")
                        VStack{
                            Text("Date :")
                            Text("Score :")
                        }
                    }
                    HStack{
                        Image("basketkuning")
                        VStack{
                            Text("Date :")
                            Text("Score :")
                        }
                    }
                    HStack{
                        Image("basketijo")
                        VStack{
                            Text("Date :")
                            Text("Score :")
                        }
                    }

                }
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    History()
}
