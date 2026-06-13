//
//  ContentView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI
import SwiftData
import ImageIO

/// 展示に含まれる1枚分の写真情報です。
struct ExhibitionPhoto {
    let image: UIImage
    let title: String
    let comment: String
    let cameraInfo: CameraInfo
}

/// ホーム画面で表示する写真展チケットのデータです。
struct ExhibitionTicket: Identifiable {
    let id: String
    let title: String
    let comment: String
    let photoCount: Int
    let coverImage: UIImage?
    let photos: [ExhibitionPhoto]
    let photosData: Data
    let backgroundImageName: String
    let publishedAt: Date
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExhibitionRecord.publishedAt, order: .reverse) private var records: [ExhibitionRecord]

    @State private var isShowingAddExhibitionView = false
    @State private var addExhibitionFlowID = UUID()
    @State private var isSavingExhibition = false
    @State private var preloadingTicketID: String?
    @State private var selectedTicket: ExhibitionTicket?
    @State private var animatedTicket: ExhibitionTicket?
    @State private var ticketPendingEnd: ExhibitionTicket?
    @State private var showTicketOverlay = false
    @State private var showExhibitionPublishedMessage = false
    @State private var animationPhase = 0
    @State private var seamShift: CGFloat = 0
    @State private var ticketVisible = true
    @State private var showEntranceOverlay = false
    @State private var entrancePhase = 0
    @State private var entranceRevealProgress: CGFloat = 0
    @State private var showExhibitionDetail = false
    @State private var hideHomeContentDuringEntrance = false
    @State private var hideHomeInterfaceDuringTicketUse = false

    private let museumTitle = "My Museum"

    var body: some View {
        NavigationStack {
            ZStack {
                // 遷移中にホームを消したとき、白い空白ではなく黒背景が見えるようにします。
                Color.black
                    .ignoresSafeArea()

                ZStack {
                    Image("home_picture")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    GeometryReader { proxy in
                        let tickets = ticketsFromRecords()

                        if tickets.isEmpty {
                            EmptyMuseumView {
                                openAddExhibitionView()
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 110)
                            .padding(.bottom, 48)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 22) {
                                    // チケットの初期位置を画面の下半分に置くための余白です。
                                    Color.clear
                                        .frame(height: proxy.size.height * 0.42)

                                    ActiveExhibitionsHeader()

                                    VStack(spacing: 18) {
                                        ForEach(tickets) { ticket in
                                            InteractiveMuseumTicket(
                                                ticket: ticket,
                                                onTap: {
                                                    selectTicketAndStartEntrance(ticket)
                                                },
                                                onLongPress: {
                                                    ticketPendingEnd = ticket
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 26)
                                // 最後のチケットも固定ボタンの上まで動かせるよう、下に十分な余白を作ります。
                                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 150, 170))
                            }
                        }
                    }
                    .opacity(hideHomeInterfaceDuringTicketUse ? 0 : 1)
                    .animation(.easeInOut(duration: 0.28), value: hideHomeInterfaceDuringTicketUse)

                    if !records.isEmpty {
                        VStack {
                            Spacer()

                            CreateExhibitionButton(title: "新しい展示を作る") {
                                openAddExhibitionView()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 48)
                        }
                        // チケットはこの固定ボタンの背面を通ってスクロールします。
                        .zIndex(9)
                        .opacity(hideHomeInterfaceDuringTicketUse ? 0 : 1)
                        .animation(.easeInOut(duration: 0.28), value: hideHomeInterfaceDuringTicketUse)
                    }

                    VStack {
                        ZStack(alignment: .topLeading) {
                            // スクロールしたチケットが上に重なっても、タイトルが背景に溶けないようにします。
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.46),
                                    Color.black.opacity(0.18),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 150)
                            .ignoresSafeArea(edges: .top)

                            HStack(alignment: .center) {
                                Text(museumTitle)
                                    .font(.system(size: 34, weight: .regular, design: .serif))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 26)
                        }

                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .zIndex(10)
                    .opacity(hideHomeInterfaceDuringTicketUse ? 0 : 1)
                    .animation(.easeInOut(duration: 0.28), value: hideHomeInterfaceDuringTicketUse)
                }
                .opacity(hideHomeContentDuringEntrance ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: hideHomeContentDuringEntrance)
            }
            .fullScreenCover(isPresented: $isShowingAddExhibitionView) {
                ZStack {
                    NavigationStack {
                        AddExhibitionView { title, comment, photoCount, coverImage, photos, backgroundImageName in
                            guard !isSavingExhibition else { return }
                            isSavingExhibition = true

                            saveTicket(
                                title: title,
                                comment: comment,
                                photoCount: photoCount,
                                coverImage: coverImage,
                                photos: photos,
                                backgroundImageName: backgroundImageName
                            ) { didSave in
                                isSavingExhibition = false
                                guard didSave else { return }

                                // 保存完了後にメッセージを表示し、My Museum画面へ戻します。
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showExhibitionPublishedMessage = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    finishAddExhibitionFlow()
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("閉じる") {
                                    finishAddExhibitionFlow()
                                }
                                .disabled(isSavingExhibition)
                            }
                        }
                    }

                    if isSavingExhibition || showExhibitionPublishedMessage {
                        Color.black.opacity(0.22)
                            .ignoresSafeArea()

                        if isSavingExhibition {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)

                                Text("保存しています…")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                            .zIndex(10)
                        } else {
                            Text("展示を開催しました")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(Color.black.opacity(0.72))
                                .clipShape(Capsule())
                                .transition(.opacity)
                                .zIndex(10)
                        }
                    }
                }
                .id(addExhibitionFlowID)
                .interactiveDismissDisabled(isSavingExhibition)
            }
            .alert(
                endExhibitionDialogTitle,
                isPresented: endExhibitionDialogBinding
            ) {
                Button("展示を終了する", role: .destructive) {
                    endPendingExhibition()
                }

                Button("キャンセル", role: .cancel) {
                    ticketPendingEnd = nil
                }
            } message: {
                Text("この展示と作品情報は削除されます。\nこの操作は取り消せません。")
            }
            .overlay {
                if showTicketOverlay, let animatedTicket {
                    TicketUseOverlay(
                        ticket: animatedTicket,
                        animationPhase: animationPhase,
                        seamShift: seamShift,
                        ticketVisible: ticketVisible
                    )
                    .transition(
                        .scale(scale: 0.88)
                            .combined(with: .opacity)
                    )
                    .zIndex(3)
                }
            }
            .overlay {
                if showExhibitionDetail, let activeTicket = selectedTicket {
                    GalleyView(
                        ticket: activeTicket,
                        onExitToHome: resetToHome
                    )
                    .zIndex(3)
                    .transition(.identity)
                }
            }
            .overlay {
                if showEntranceOverlay, let activeTicket = selectedTicket {
                    ExhibitionEntranceOverlay(
                        ticket: activeTicket,
                        phase: entrancePhase,
                        revealProgress: entranceRevealProgress
                    )
                    .zIndex(4)
                    .allowsHitTesting(true)
                }
            }
        }
    }

    /// 展示作成画面を滑らかに開きます。
    private func openAddExhibitionView() {
        guard !showTicketOverlay, !showEntranceOverlay, !showExhibitionDetail else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            isShowingAddExhibitionView = true
        }
    }

    /// 終了確認ダイアログに展示タイトルを表示します。
    private var endExhibitionDialogTitle: String {
        guard let ticketPendingEnd else { return "展示を終了しますか？" }
        return "「\(ticketPendingEnd.title)」の展示を終了しますか？"
    }

    /// 削除候補の有無と確認ダイアログの表示状態を連動させます。
    private var endExhibitionDialogBinding: Binding<Bool> {
        Binding(
            get: { ticketPendingEnd != nil },
            set: { isPresented in
                if !isPresented {
                    ticketPendingEnd = nil
                }
            }
        )
    }

    /// 確認された展示だけをSwiftDataから削除します。
    private func endPendingExhibition() {
        guard let ticket = ticketPendingEnd else { return }
        guard let record = records.first(where: {
            String(describing: $0.persistentModelID) == ticket.id
        }) else {
            ticketPendingEnd = nil
            return
        }

        modelContext.delete(record)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }

        ticketPendingEnd = nil
    }

    /// 展示説明画面からホーム画面へ戻るときに、遷移用の状態を元に戻します。
    private func resetToHome() {
        showExhibitionDetail = false
        selectedTicket = nil
        animatedTicket = nil
        hideHomeContentDuringEntrance = false
        hideHomeInterfaceDuringTicketUse = false
    }

    /// チケットを1回タップしただけで、中央表示から切断アニメーションまで自動で進めます。
    private func selectTicketAndStartEntrance(_ ticket: ExhibitionTicket) {
        guard !showTicketOverlay else { return }

        selectedTicket = ticket
        // 展示写真の先読みでselectedTicketが更新されても、演出中のチケットは同じ見た目に固定します。
        animatedTicket = ticket
        animationPhase = 0
        seamShift = 0
        ticketVisible = true
        preloadPhotosForSelectedTicket()

        // 背景画像は残し、ホームの文字・チケット一覧・追加ボタンだけを消します。
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
            hideHomeInterfaceDuringTicketUse = true
            showTicketOverlay = true
        }

        // 「中央へ浮かぶ → 静止して待つ」が見えるように、切断まで十分な間を取ります。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard showTicketOverlay else { return }
            guard animatedTicket?.id == ticket.id else { return }
            guard animationPhase == 0 else { return }
            playTicketCutAnimation()
        }
    }

    /// 展示作成画面を閉じて、My Museum画面へ確実に戻します。
    private func finishAddExhibitionFlow() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showExhibitionPublishedMessage = false
            isShowingAddExhibitionView = false
        }
        isSavingExhibition = false

        // 次に展示作成を開いたとき、前回の奥の画面が残らないように作り直します。
        addExhibitionFlowID = UUID()
    }

    /// チケットを破る演出を順番に再生し、完了したら展示説明へ進みます。
    private func playTicketCutAnimation() {
        // phase 1: チケット全体を少し沈ませます。最初の反応だけを見せます。
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            animationPhase = 1
        }
        
        // phase 3: 細かい揺れは入れず、右側の半券を一気に切り離します。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) {
                animationPhase = 3
            }
        }

        // phase 6: 左右の半券をまとめてフェードアウトします。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.easeOut(duration: 0.22)) {
                animationPhase = 6
            }
        }

        // 破れ演出が終わったらチケット本体を完全に消します。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            ticketVisible = false
        }

        // チケットが消えた直後に暗転へ入り、間延びしないようにします。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.84) {
            // 暗転開始時点でチケット関連UIを確実に隠します
            showTicketOverlay = false
            animatedTicket = nil
            seamShift = 0
            playExhibitionEntranceAnimation()
        }
    }
    
    /// チケット使用後の「展示室へ入室」演出を再生します。
    private func playExhibitionEntranceAnimation() {
        entrancePhase = 0
        entranceRevealProgress = 0
        showEntranceOverlay = true

        // 先読みがまだ終わっていない場合だけ、ここでも読み込みを開始します。
        preloadPhotosForSelectedTicket()
        
        // phase 1: 暗転（約1秒）
        withAnimation(.easeInOut(duration: 1.0)) {
            entrancePhase = 1
        }
        
        // phase 2: タイトルをゆっくり表示（約1秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeInOut(duration: 1.0)) {
                entrancePhase = 2
            }
        }
        
        // phase 3: タイトルをしっかり読めるだけ見せた後、中央の白い光を拡張開始（約1.8秒）
        // 1.05 + 1.0 でタイトル出現完了。その後さらに約2.25秒保持。
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            // 白い光が広がる前にホームを消すと、前のタイトルが一瞬見えるのを防げます。
            hideHomeContentDuringEntrance = true
            withAnimation(.easeInOut(duration: 1.8)) {
                entrancePhase = 3
                entranceRevealProgress = 1
            }
        }
        
        // 白が最大になる少し前に展示を裏側へ用意し、初回描画のかくつきを白で隠します。
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.75) {
            showExhibitionDetail = true
        }

        // 展示の準備後に画面全体を白で包みます。
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.1) {
            withAnimation(.linear(duration: 0.12)) {
                entrancePhase = 4
            }
        }
        
        // phase 5: 白を消すと、そのまま展示の1枚目が見えるようになります。
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.25) {
            withAnimation(.easeInOut(duration: 0.72)) {
                entrancePhase = 5
            }
        }
        
        // 完了後にオーバーレイを閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.02) {
            showEntranceOverlay = false
            entrancePhase = 0
            entranceRevealProgress = 0
            animationPhase = 0
            ticketVisible = true
        }
    }

    /// 写真の変換を別の処理で行い、完了後にSwiftDataへ展示情報を保存します。
    private func saveTicket(
        title: String,
        comment: String,
        photoCount: Int,
        coverImage: UIImage?,
        photos: [ExhibitionPhoto],
        backgroundImageName: String,
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let storedPhotos = photos.compactMap { photo -> StoredPhoto? in
                guard let imageData = photo.image.jpegData(compressionQuality: 0.9) else { return nil }
                return StoredPhoto(
                    imageData: imageData,
                    title: photo.title,
                    comment: photo.comment,
                    cameraInfo: photo.cameraInfo
                )
            }

            let encoder = JSONEncoder()
            guard let photosData = try? encoder.encode(storedPhotos) else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            let coverImageData = coverImage?.jpegData(compressionQuality: 0.9)

            DispatchQueue.main.async {
                let record = ExhibitionRecord(
                    title: title,
                    comment: comment,
                    photoCount: photoCount,
                    backgroundImageName: backgroundImageName,
                    publishedAt: Date(),
                    coverImageData: coverImageData,
                    photosData: photosData
                )
                modelContext.insert(record)

                do {
                    try modelContext.save()
                    completion(true)
                } catch {
                    completion(false)
                }
            }
        }
    }

    /// チケット確認中に展示写真を裏で復元し、入場アニメーションと処理が重ならないようにします。
    private func preloadPhotosForSelectedTicket() {
        guard let ticket = selectedTicket else { return }
        guard ticket.photos.isEmpty else { return }
        guard preloadingTicketID != ticket.id else { return }

        preloadingTicketID = ticket.id
        let ticketID = ticket.id
        let photosData = ticket.photosData

        DispatchQueue.global(qos: .userInitiated).async {
            let decoder = JSONDecoder()
            let storedPhotos = (try? decoder.decode([StoredPhoto].self, from: photosData)) ?? []

            let photos = storedPhotos.compactMap { stored -> ExhibitionPhoto? in
                guard let source = CGImageSourceCreateWithData(stored.imageData as CFData, nil) else { return nil }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1800
                ]
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
                let uiImage = UIImage(cgImage: cgImage)

                return ExhibitionPhoto(
                    image: uiImage,
                    title: stored.title,
                    comment: stored.comment,
                    cameraInfo: stored.cameraInfo
                )
            }

            DispatchQueue.main.async {
                if preloadingTicketID == ticketID {
                    preloadingTicketID = nil
                }

                guard let currentTicket = selectedTicket else { return }
                guard currentTicket.id == ticketID, currentTicket.photos.isEmpty else { return }

                selectedTicket = ExhibitionTicket(
                    id: currentTicket.id,
                    title: currentTicket.title,
                    comment: currentTicket.comment,
                    photoCount: currentTicket.photoCount,
                    coverImage: currentTicket.coverImage,
                    photos: photos,
                    photosData: currentTicket.photosData,
                    backgroundImageName: currentTicket.backgroundImageName,
                    publishedAt: currentTicket.publishedAt
                )
            }
        }
    }

    /// SwiftData保存データを画面表示用データへ変換します。
    private func ticketsFromRecords() -> [ExhibitionTicket] {
        return records.map { record in
            return ExhibitionTicket(
                id: String(describing: record.persistentModelID),
                title: record.title,
                comment: record.comment,
                photoCount: record.photoCount,
                coverImage: record.coverImageData.flatMap { UIImage(data: $0) },
                photos: [],
                photosData: record.photosData,
                backgroundImageName: record.backgroundImageName,
                publishedAt: record.publishedAt
            )
        }
    }
}

/// 展示がまだないときに、最初の展示作成を案内します。
struct EmptyMuseumView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Text("まだ展示がありません")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("あなたの写真で、はじめての\n写真展を作ってみましょう")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(9)
            }

            Spacer()

            CreateExhibitionButton(title: "最初の展示を作る", action: onCreate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// ホーム画面下部に表示する展示作成ボタンです。
struct CreateExhibitionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .regular))

                Text(title)
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(Color(red: 0.12, green: 0.09, blue: 0.06))
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.84, blue: 0.62),
                        Color(red: 0.84, green: 0.68, blue: 0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 18, y: 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// 通常タップと長押しを競合させず、チケット操作を判定します。
struct InteractiveMuseumTicket: View {
    let ticket: ExhibitionTicket
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var feedbackTrigger = 0

    var body: some View {
        TicketView(ticket: ticket)
            .contentShape(Rectangle())
            .gesture(ticketGesture)
            .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onTap()
            }
    }

    /// 約0.55秒の長押しと通常タップを、どちらか一方だけ実行します。
    private var ticketGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.55, maximumDistance: 20)
            .exclusively(before: TapGesture())
            .onEnded { result in
                switch result {
                case .first:
                    feedbackTrigger += 1
                    onLongPress()

                case .second:
                    onTap()
                }
            }
    }
}

/// 開催中の展示チケット一覧の見出しです。
struct ActiveExhibitionsHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("開催中の展示")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.92))

            Rectangle()
                .fill(.white.opacity(0.32))
                .frame(height: 1)
        }
        .padding(.top, 2)
    }
}

/// 選択したチケットを中央に浮かべ、切断アニメーションを表示します。
struct TicketUseOverlay: View {
    let ticket: ExhibitionTicket
    let animationPhase: Int
    let seamShift: CGFloat
    let ticketVisible: Bool

    var body: some View {
        ZStack {
            // 背景画像の雰囲気を残すため、暗くしすぎない薄いレイヤーにします。
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            if ticketVisible {
                TicketCutAnimationView(
                    ticket: ticket,
                    animationPhase: animationPhase,
                    seamShift: seamShift
                )
                .frame(height: 170)
                .padding(.horizontal, 20)
                .scaleEffect(overlayScale(phase: animationPhase))
                .offset(y: overlayOffsetY(phase: animationPhase))
                .opacity(animationPhase == 6 ? 0.0 : 1.0)
            }
        }
        .allowsHitTesting(false)
    }
    
    /// フェーズごとの全体スケールです（沈み込みと溜め）。
    private func overlayScale(phase: Int) -> CGFloat {
        switch phase {
        case 1: return 0.985
        case 2: return 0.992
        case 6: return 0.985
        default: return 1.0
        }
    }
    
    /// フェーズごとの全体Y移動です（最初に沈み込む）。
    private func overlayOffsetY(phase: Int) -> CGFloat {
        switch phase {
        case 1: return 9
        case 2: return 5
        case 6: return 8
        default: return 0
        }
    }
}

/// 展示室へ入室するための暗転・タイトル・光の演出オーバーレイです。
struct ExhibitionEntranceOverlay: View {
    let ticket: ExhibitionTicket
    let phase: Int
    let revealProgress: CGFloat
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(darkOverlayOpacity(phase: phase))
                .ignoresSafeArea()
            
            // 中央の白い光です。軽い円を2枚重ねて、前の柔らかい広がりに近づけます。
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 360, height: 360)
                    .scaleEffect(0.8 + revealProgress * 3.8)

                Circle()
                    .fill(Color.white.opacity(0.52))
                    .frame(width: 190, height: 190)
                    .scaleEffect(0.9 + revealProgress * 5.4)
            }
            .opacity(lightOpacity(phase: phase))
            
            // 全体を白で包む層。phase4で最大化し、phase5で晴れる
            Color.white
                .opacity(whiteWrapOpacity(phase: phase))
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text("Exhibition \(String(format: "%02d", max(ticket.photoCount, 1)))")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.84))
                
                Text(ticket.title)
                    .font(.system(size: 36, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Text(themeText)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .opacity(titleOpacity(phase: phase))
            .scaleEffect(phase >= 2 && phase < 4 ? 1 : 0.95)
        }
    }
    
    /// 展示テーマの補助テキストを返します。
    private var themeText: String {
        if !ticket.comment.isEmpty {
            return ticket.comment
        }
        return "\(ticket.photoCount)作品の展示"
    }
    
    /// フェーズごとの暗転濃度です。
    private func darkOverlayOpacity(phase: Int) -> CGFloat {
        switch phase {
        case 0: return 0
        case 1: return 1
        case 2: return 1
        case 3: return 0.96
        case 4: return 0.0
        case 5: return 0.0
        default: return 0
        }
    }

    /// 中央タイトルの濃さです。白画面のあとに残像として見えないよう、phase4以降は消します。
    private func titleOpacity(phase: Int) -> CGFloat {
        switch phase {
        case 2, 3: return 1
        default: return 0
        }
    }

    /// 中央の光の濃さです。展示説明画面へ移るタイミングでは消します。
    private func lightOpacity(phase: Int) -> CGFloat {
        switch phase {
        case 3, 4: return 1
        default: return 0
        }
    }
    
    /// 画面全体を白く包む層の不透明度です。
    private func whiteWrapOpacity(phase: Int) -> CGFloat {
        switch phase {
        case 0, 1, 2: return 0
        case 3: return min(0.92, 0.15 + revealProgress * 0.77)
        case 4: return 1
        case 5: return 0
        default: return 0
        }
    }
}

/// チケットが左右に破れる見た目を作るビューです。
struct TicketCutAnimationView: View {
    let ticket: ExhibitionTicket
    let animationPhase: Int
    let seamShift: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let splitX = width * 0.68
            let leftState = leftTransform(phase: animationPhase)
            let rightState = rightTransform(phase: animationPhase)

            ZStack {
                // 左側チケット片
                TicketView(
                    ticket: ticket,
                    usesPaperTexture: false,
                    shadowOpacity: 0.025,
                    shadowRadius: 3,
                    shadowYOffset: 2
                )
                    .frame(width: width, height: proxy.size.height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: splitX)
                    }
                    .offset(x: leftState.x, y: leftState.y)
                    .rotationEffect(.degrees(leftState.zRotation))
                    .scaleEffect(leftState.scale)
                    .opacity(leftState.opacity)

                // 右側チケット片
                TicketView(
                    ticket: ticket,
                    usesPaperTexture: false,
                    shadowOpacity: 0.025,
                    shadowRadius: 3,
                    shadowYOffset: 2
                )
                    .frame(width: width, height: proxy.size.height)
                    .mask(alignment: .trailing) {
                        Rectangle().frame(width: width - splitX)
                    }
                    .offset(x: rightState.x, y: rightState.y)
                    .rotationEffect(.degrees(rightState.zRotation))
                    .scaleEffect(rightState.scale)
                    .opacity(rightState.opacity)

            }
        }
    }

    /// フェーズごとの左片の動きです。
    private func leftTransform(phase: Int) -> TicketPieceTransform {
        switch phase {
        case 1:
            return .init(x: -1, y: 0, zRotation: -0.2, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        case 2:
            return .init(x: -3, y: 0, zRotation: -0.8, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        case 3:
            return .init(x: -4, y: 0, zRotation: -1.0, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        case 4:
            return .init(x: -4, y: 0, zRotation: -1.0, x3D: 0, y3D: 0, scale: 1, opacity: 0.92)
        case 5:
            return .init(x: -3, y: 1, zRotation: -0.7, x3D: 0, y3D: 0, scale: 0.998, opacity: 0.35)
        case 6:
            return .init(x: -3, y: 3, zRotation: -0.7, x3D: 0, y3D: 0, scale: 0.99, opacity: 0.0)
        default:
            return .init(x: 0, y: 0, zRotation: 0, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        }
    }

    /// フェーズごとの右片の動きです。
    private func rightTransform(phase: Int) -> TicketPieceTransform {
        switch phase {
        case 1:
            return .init(x: 0, y: 0, zRotation: 0.2, x3D: 0, y3D: 0.8, scale: 1, opacity: 1)
        case 2:
            return .init(x: 6, y: 0, zRotation: 0.8, x3D: 0, y3D: 2, scale: 1, opacity: 1)
        case 3:
            return .init(x: 58, y: -5, zRotation: 3.2, x3D: 0, y3D: 0, scale: 1, opacity: 0.92)
        case 4:
            return .init(x: 58, y: -7, zRotation: 3.8, x3D: -1, y3D: 4, scale: 0.998, opacity: 0.82)
        case 5:
            return .init(x: 78, y: -3, zRotation: 4.2, x3D: 0, y3D: 4, scale: 0.992, opacity: 0.25)
        case 6:
            return .init(x: 82, y: 0, zRotation: 4.2, x3D: 0, y3D: 3, scale: 0.982, opacity: 0.0)
        default:
            return .init(x: 0, y: 0, zRotation: 0, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        }
    }
}

/// チケット片の位置・角度・透明度をまとめるための構造体です。
struct TicketPieceTransform {
    let x: CGFloat
    let y: CGFloat
    let zRotation: CGFloat
    let x3D: CGFloat
    let y3D: CGFloat
    let scale: CGFloat
    let opacity: CGFloat
}

/// 右側の半券が切り離される瞬間に、控えめな紙の粒を出す演出です。
struct TicketPaperParticleView: View {
    let isActive: Bool
    let splitX: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 1.5 + CGFloat(index % 2), height: 1.5 + CGFloat(index % 2))
                        .offset(
                            x: isActive ? particleX(index) : 0,
                            y: isActive ? particleY(index) : 0
                        )
                        .opacity(isActive ? 0.0 : 0.95)
                        .scaleEffect(isActive ? 0.5 : 1.0)
                        .position(x: splitX, y: proxy.size.height * 0.52)
                        .animation(
                            .easeOut(duration: 0.35).delay(Double(index) * 0.006),
                            value: isActive
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func particleX(_ i: Int) -> CGFloat {
        let sign: CGFloat = i % 2 == 0 ? -1 : 1
        return sign * (6 + CGFloat((i * 5) % 12))
    }

    private func particleY(_ i: Int) -> CGFloat {
        CGFloat(-8 + (i % 5) * 3)
    }
}

/// 写真展のチケット見た目を表示します。
struct TicketView: View {
    let ticket: ExhibitionTicket
    var usesPaperTexture = true
    var shadowOpacity: CGFloat = 0.08
    var shadowRadius: CGFloat = 8
    var shadowYOffset: CGFloat = 4

    private let ticketPaperColor = Color(red: 0.95, green: 0.94, blue: 0.90)
    private let ticketInkColor = Color(red: 0.27, green: 0.25, blue: 0.21)

    var body: some View {
        GeometryReader { proxy in
            let splitX = proxy.size.width * 0.68

            HStack(spacing: 0) {
                TicketMainArea(ticket: ticket, ticketInkColor: ticketInkColor, ticketPaperColor: ticketPaperColor)
                    .frame(width: splitX)
                TicketStubArea(ticketInkColor: ticketInkColor, ticketPaperColor: ticketPaperColor)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(ticketPaperColor)
            .overlay {
                if usesPaperTexture {
                    TicketPaperTexture()
                        .clipShape(TicketShape(cornerRadius: 10, sideNotchRadius: 16))
                        .allowsHitTesting(false)
                }
            }
            .clipShape(TicketShape(cornerRadius: 10, sideNotchRadius: 16))
            .overlay(
                TicketShape(cornerRadius: 10, sideNotchRadius: 16)
                    .stroke(ticketInkColor.opacity(0.14), lineWidth: 1)
            )
            .overlay {
                TicketPerforationCutout(xPosition: splitX)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
        .frame(height: 130)
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
    }
}

/// チケットの左側メイン情報を表示します。
struct TicketMainArea: View {
    let ticket: ExhibitionTicket
    let ticketInkColor: Color
    let ticketPaperColor: Color

    var body: some View {
        HStack(spacing: 10) {
            TicketThumbnailView(ticket: ticket)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 5) {
                Text(ticket.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ticketInkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(publishedDateText(ticket.publishedAt))-")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ticketInkColor.opacity(0.8))

                Text("全\(ticket.photoCount)作品")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ticketInkColor.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(ticketPaperColor)
    }

    private func publishedDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

/// チケット内の正方形サムネイルを表示します。
struct TicketThumbnailView: View {
    let ticket: ExhibitionTicket

    var body: some View {
        Group {
            // 作品写真の先読みが終わっても、チケットには選択したカバー写真を表示し続けます。
            if let image = ticket.coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.28))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .frame(width: 96, height: 96)
        .clipped()
    }
}

/// チケットの右側スタブを表示します。
struct TicketStubArea: View {
    let ticketInkColor: Color
    let ticketPaperColor: Color

    var body: some View {
        VStack {
            Spacer()
            Text("入場する")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ticketInkColor.opacity(0.85))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ticketPaperColor)
    }
}

/// 右側半円ノッチ付きの再利用可能なチケット形状です。
struct TicketShape: Shape {
    var cornerRadius: CGFloat = 10
    var sideNotchRadius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) * 0.2)
        let notchR = min(sideNotchRadius, rect.height * 0.4)
        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: left + r, y: top))
        path.addLine(to: CGPoint(x: right - r, y: top))
        path.addArc(
            center: CGPoint(x: right - r, y: top + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: right, y: rect.midY - notchR))
        path.addArc(
            center: CGPoint(x: right, y: rect.midY),
            radius: notchR,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: right, y: bottom - r))
        path.addArc(
            center: CGPoint(x: right - r, y: bottom - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: left + r, y: bottom))

        path.addArc(
            center: CGPoint(x: left + r, y: bottom - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: left, y: top + r))
        path.addArc(
            center: CGPoint(x: left + r, y: top + r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// チケット中央の上下半円と点線をくり抜くための描画Viewです。
struct TicketPerforationCutout: View {
    let xPosition: CGFloat
    
    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            
            ZStack {
                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: 0)
                
                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: h)
                
                VStack(spacing: 4) {
                    ForEach(0..<14, id: \.self) { _ in
                        Rectangle()
                            .fill(.black)
                            .frame(width: 2, height: 4)
                    }
                }
                .position(x: xPosition, y: h / 2)
            }
        }
    }
}

/// チケットに薄い紙の質感を重ねるためのビューです。
struct TicketPaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<360 {
                let x = pseudoRandom(i * 17 + 3) * size.width
                let y = pseudoRandom(i * 31 + 11) * size.height
                let w = 0.8 + pseudoRandom(i * 13 + 7) * 1.8
                let h = 0.8 + pseudoRandom(i * 19 + 5) * 1.8
                let alpha = 0.025 + pseudoRandom(i * 23 + 2) * 0.055
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
                    with: .color(.black.opacity(alpha))
                )
            }
        }
        .blendMode(.multiply)
        .opacity(0.82)
    }
    
    private func pseudoRandom(_ seed: Int) -> CGFloat {
        let x = sin(Double(seed) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(x - floor(x))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ExhibitionRecord.self], inMemory: true)
}
