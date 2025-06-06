//
//  HomeView.swift
//  iTour
//
//  Created by Ramdan on 14/05/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var navManager: NavigationManager<Routes>
    @StateObject private var shakeMotionManager = ShakeMotionManager()
    @StateObject private var nfcReader = NFCReader()
    @State private var isWaitOver = true
    @State private var progress = 0.3
    @State private var isDetectingShake = false
    @State private var manuallyShowSheet: Bool = false
    @State private var isShowHint: Bool = false
    @Query(filter: #Predicate<TagViewState> { $0.isDone == true }) var completedTags: [TagViewState]
    @Query(filter: #Predicate<GameViewState> { $0.isDone == true }) var completedGames: [GameViewState]
    @StateObject private var haptic = HapticModel()
    
    var showSheetBinding: Binding<Bool> {
        Binding(get: {
            isWaitOver && (shakeMotionManager.didShakeDetected && isDetectingShake || manuallyShowSheet)
        }, set: { newValue in
            if !newValue {
                shakeMotionManager.didShakeDetected = false
                isWaitOver = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    isWaitOver = true
                    manuallyShowSheet = false
                }
            }
        })
    }
    
    var body: some View {
        ZStack {
            Image("bg")
                .resizable()
                .scaledToFill()
            if isShowHint {
                VStack {
                    Spacer()
                        .frame(height: 100)
                    HStack(spacing: 10 ) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .symbolEffect(.wiggle)
                            .font(.largeTitle)
                        Text("Shake your phone to reveal hint")
                            .multilineTextAlignment(.center)
                            .fontWidth(.expanded)
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(width: 300)
                    .background(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(lineWidth: 0.1)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 5)
                    }
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
                .id(UUID())
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isShowHint = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                
                                isShowHint = false
                                
                            }
                        }
                    }) {
                        Circle()
                            .overlay {
                                Image(systemName: "lightbulb.min")
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 40, height: 40)
                            .foregroundStyle(
                                isShowHint
                                ? .gray
                                : .blue
                            )
                    }
                    .disabled(isShowHint)
                }
                .padding(.top, 50)
                .padding(.trailing, 40)
                Spacer()
            }
            VStack(spacing: 20) {
                Text("Have fun and explore!")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .fontWidth(.expanded)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 60))
                    .padding(.vertical, 40)
                
                
                Text(completedTags.count < 10 ?
                     "You've discovered \(completedTags.count)/10 hidden spots in ADA!"
                     : "You've discovered all hidden spots in ADA!"
                )
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(Color.black)
                .fontWidth(.expanded)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
                if completedTags.count >= 10 {
                    Text(completedGames.count < 15 ?
                         "You've completed \(completedGames.count)/15 minigames"
                         : "You've completed all of our games. Congratulations!"
                    )
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.black)
                    .fontWidth(.expanded)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    nfcReader.beginScanning()
                }) {
                    
                    Text("Scan Tag")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 264, height: 51)
                        .background(Color.primaryBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(20)
                        .fontWidth(.expanded)
                }
                .padding(.top)
            }
            .padding()
            .onChange(of: shakeMotionManager.didShakeDetected, {
                if(shakeMotionManager.didShakeDetected && isDetectingShake && isWaitOver) {
                    haptic.playHaptic(duration: 0.7)
                }
            })
            .onAppear {
                shakeMotionManager.didShakeDetected = false
                isDetectingShake = true
                shakeMotionManager.detectShakeMotion()
                
                nfcReader.assignOnScan {
                    if(nfcReader.scannedMessage.isEmpty) {
                        return;
                    }
                    
                    let cleaned = nfcReader.scannedMessage.trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
                    
                    let tagId = extractTagId(URL(string: cleaned))
                    if let tagId = tagId {
                        navManager.path.append(.instruction(tagId: tagId))
                    }
                }
            }
            .onDisappear {
                isDetectingShake = false
                shakeMotionManager.resetShakeDetection()
                shakeMotionManager.stopShakeDetection()
            }
            .sheet(
                isPresented: showSheetBinding,
                onDismiss: {
                    isWaitOver = false
                    shakeMotionManager.didShakeDetected = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                        isWaitOver = true
                        shakeMotionManager.detectShakeMotion()
                    }
                }) {
                    BottomSheetView(shakeMotionManager: shakeMotionManager)
                        .presentationCornerRadius(30)
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.fraction(0.45)])
                }
        }
    }
}

#Preview {
    HomeView()
}
