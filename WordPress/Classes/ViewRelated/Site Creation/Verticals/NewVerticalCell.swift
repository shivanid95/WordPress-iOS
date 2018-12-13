import UIKit
import Gridicons

final class NewVerticalCell: UITableViewCell, ModelSettableCell {
    @IBOutlet weak var title: UILabel!

    var model: SiteVertical? {
        didSet {
            title.text = model?.title
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        styleTitle()
        styleAccessoryView()
    }

    override func prepareForReuse() {
        title.text = ""
    }

    private func styleTitle() {
        title.font = WPStyleGuide.fontForTextStyle(.body, fontWeight: .regular)
        title.textColor = WPStyleGuide.darkGrey()
    }

    private func styleAccessoryView() {
        let accessoryImage = Gridicon.iconOfType(.chevronRight).imageWithTintColor(WPStyleGuide.greyLighten20())
        accessoryView = UIImageView(image: accessoryImage)
    }
}
