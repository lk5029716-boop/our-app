import UIKit
import UniformTypeIdentifiers
import MobileCoreServices
import AVFoundation

/**
 * iOS Keyboard Extension layer (UIInputViewController).
 *
 * Capability strategy:
 *  Concurrently write kUTTypeGIF + kUTTypeMPEG4 (UTType.gif / .mpeg4Movie)
 *  onto UIPasteboard so the receiving app natively selects a supported type.
 *
 * Fallback: UIActivityViewController share sheet over the host app.
 */
class KeyboardViewController: UIInputViewController {

    private let bg = UIColor(red: 0.043, green: 0.043, blue: 0.059, alpha: 1) // #0B0B0F
    private let indigo = UIColor(red: 0.388, green: 0.400, blue: 0.945, alpha: 1)
    private let violet = UIColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1)
    private let muted = UIColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1)

    private var collectionView: UICollectionView!
    private var searchField: UITextField!
    private var overlay: UIView!
    private var statusLabel: UILabel!
    private var spinner: UIActivityIndicatorView!

    private var items: [GifItem] = GifItem.demo
    private let engine = MediaEngineIOS()
    private let bridgeChannel = "com.smartmedia.app/keyboard_bridge"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bg
        buildChrome()
        buildGrid()
        buildOverlay()
    }

    // MARK: - Layout

    private func buildChrome() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = UIColor(white: 0.07, alpha: 0.8)
        view.addSubview(header)

        let logo = UILabel()
        logo.text = "SmartMedia"
        logo.font = .systemFont(ofSize: 17, weight: .bold)
        logo.textColor = .white
        logo.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(logo)

        let pulse = UIView()
        pulse.backgroundColor = UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1)
        pulse.layer.cornerRadius = 4
        pulse.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(pulse)

        let engineLabel = UILabel()
        engineLabel.text = "Engine: Active"
        engineLabel.font = .systemFont(ofSize: 12, weight: .medium)
        engineLabel.textColor = muted
        engineLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(engineLabel)

        let gear = UIButton(type: .system)
        gear.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        gear.tintColor = muted
        gear.translatesAutoresizingMaskIntoConstraints = false
        gear.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        header.addSubview(gear)

        searchField = UITextField()
        searchField.placeholder = "Search trending GIFs..."
        searchField.textColor = .white
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search trending GIFs...",
            attributes: [.foregroundColor: muted]
        )
        searchField.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)
        searchField.layer.cornerRadius = 22
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 44))
        searchField.leftViewMode = .always
        let mag = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        mag.tintColor = muted
        mag.frame = CGRect(x: 12, y: 12, width: 16, height: 16)
        searchField.leftView?.addSubview(mag)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.addTarget(self, action: #selector(onSearch), for: .editingChanged)
        view.addSubview(searchField)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),

            logo.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            logo.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            gear.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            gear.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            gear.widthAnchor.constraint(equalToConstant: 40),
            gear.heightAnchor.constraint(equalToConstant: 40),

            engineLabel.trailingAnchor.constraint(equalTo: gear.leadingAnchor, constant: -4),
            engineLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            pulse.trailingAnchor.constraint(equalTo: engineLabel.leadingAnchor, constant: -8),
            pulse.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            pulse.widthAnchor.constraint(equalToConstant: 8),
            pulse.heightAnchor.constraint(equalToConstant: 8),

            searchField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func buildGrid() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GifCell.self, forCellWithReuseIdentifier: GifCell.reuseId)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
        ])
    }

    private func buildOverlay() {
        overlay = UIView()
        overlay.backgroundColor = UIColor(red: 0.043, green: 0.043, blue: 0.059, alpha: 0.8)
        overlay.isHidden = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(blur)

        spinner = UIActivityIndicatorView(style: .large)
        spinner.color = indigo
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)

        statusLabel = UILabel()
        statusLabel.textColor = muted
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            blur.topAnchor.constraint(equalTo: overlay.topAnchor),
            blur.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 18),
            statusLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Actions

    @objc private func onSearch() {
        let q = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        items = q.isEmpty ? GifItem.demo : GifItem.demo.filter {
            $0.title.lowercased().contains(q.lowercased())
        }
        collectionView.reloadData()
    }

    @objc private func openSettings() {
        // Host app settings deep-link when Full Access is granted
        if let url = URL(string: UIApplication.openSettingsURLString) {
            extensionContext?.open(url, completionHandler: nil)
        }
    }

    /// Async controller: handleAssetSelection(gifUrl)
    func handleAssetSelection(_ gifUrl: String) {
        showOverlay("Inspecting target field capabilities…")
        Task {
            do {
                showOverlay("Streaming GIF into secure cache…")
                let gifURL = try await engine.downloadToCache(gifUrl)

                showOverlay("Packaging into H.264 MP4 container…")
                let mp4URL = try? await engine.transcodeGifToMp4(gifURL)

                showOverlay("Committing media to host app…")
                let wrote = engine.writeDualPasteboard(gif: gifURL, mp4: mp4URL)

                if !wrote {
                    showOverlay("Opening system share sheet…")
                    await MainActor.run {
                        openShareSheet(url: mp4URL ?? gifURL)
                    }
                } else {
                    showOverlay("Delivered to pasteboard — long-press to paste.")
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                showOverlay("Something went wrong. Try another GIF.")
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
            await MainActor.run { hideOverlay() }
        }
    }

    private func openShareSheet(url: URL) {
        // UIActivityViewController over host when field rejects both formats
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        present(vc, animated: true)
    }

    private func showOverlay(_ message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.overlay.isHidden = false
            self.spinner.startAnimating()
        }
    }

    private func hideOverlay() {
        overlay.isHidden = true
        spinner.stopAnimating()
    }
}

// MARK: - UICollectionView

extension KeyboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GifCell.reuseId, for: indexPath) as! GifCell
        cell.configure(items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleAssetSelection(items[indexPath.item].url)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let inset: CGFloat = 12 * 2 + 10
        let w = (collectionView.bounds.width - inset) / 2
        return CGSize(width: w, height: w * 0.85)
    }
}

// MARK: - Models / Cell

struct GifItem {
    let id: String
    let title: String
    let url: String

    static let demo: [GifItem] = [
        .init(id: "1", title: "Happy dance", url: "https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif"),
        .init(id: "2", title: "Thumbs up", url: "https://media.giphy.com/media/111ebonMs90YLu/giphy.gif"),
        .init(id: "3", title: "Mind blown", url: "https://media.giphy.com/media/26u4cqiYI30juCOGY/giphy.gif"),
        .init(id: "4", title: "Cat vibes", url: "https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif"),
        .init(id: "5", title: "Celebrate", url: "https://media.giphy.com/media/g9582DNuQppxC/giphy.gif"),
        .init(id: "6", title: "High five", url: "https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif"),
        .init(id: "7", title: "Coffee time", url: "https://media.giphy.com/media/3oKIPnAiaMCws8nOsE/giphy.gif"),
        .init(id: "8", title: "Wow", url: "https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif"),
    ]
}

final class GifCell: UICollectionViewCell {
    static let reuseId = "GifCell"
    private let imageView = UIImageView()
    private let badge = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1)

        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        badge.text = "GIF"
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 6
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badge)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            badge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            badge.widthAnchor.constraint(equalToConstant: 32),
            badge.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ item: GifItem) {
        imageView.image = nil
        guard let url = URL(string: item.url) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.imageView.image = img }
        }.resume()
    }
}
