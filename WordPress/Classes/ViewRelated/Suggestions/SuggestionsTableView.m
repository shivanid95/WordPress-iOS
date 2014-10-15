#import "SuggestionsTableView.h"
#import "SuggestionsTableViewCell.h"
#import "Suggestion.h"
#import "SuggestionService.h"

NSString * const CellIdentifier = @"SuggestionsTableViewCell";
CGFloat const RowHeight = 48.0f;

@interface SuggestionsTableView ()

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSNumber *siteID;
@property (nonatomic, strong) NSArray *suggestions;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, strong) NSMutableArray *searchResults;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;

@end

@implementation SuggestionsTableView


- (id)initWithSiteID:(NSNumber *)siteID
{    
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _siteID = siteID;
        _suggestions = [[SuggestionService shared] suggestionsForSiteID:_siteID];
        _searchText = @"";
        _searchResults = [[NSMutableArray alloc] init];

        _headerView = [[UIView alloc] init];
        _headerView.backgroundColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.3f];
        [_headerView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:_headerView];
                
        _tableView = [[UITableView alloc] init];
        [_tableView registerClass:[SuggestionsTableViewCell class] forCellReuseIdentifier:CellIdentifier];
        [_tableView setDataSource:self];
        [_tableView setDelegate:self];
        [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_tableView setRowHeight:RowHeight];
        [self addSubview:_tableView];
        
        // Pin the table view to the view's edges
        NSDictionary *views = @{@"headerview": self.headerView,
                                @"tableview": self.tableView };
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[headerview]|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableview]|"
                                                                          options:0
                                                                          metrics:nil
                                                                            views:views]];
        
        // Vertically arrange the header and table
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[headerview][tableview]|"
                                                                          options:0
                                                                          metrics:nil
                                                                            views:views]];

        // Add a height constraint to the table view
        self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.tableView
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:nil
                                                            multiplier:1
                                                              constant:0.f];
        self.heightConstraint.priority = 300;
        
        [self addConstraint:self.heightConstraint];
                        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(suggestionListUpdated:)
                                                     name:SuggestionListUpdatedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardDidChangeFrame:)
                                                     name:UIKeyboardDidChangeFrameNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceOrientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self setHidden:(self.searchResults.count == 0)];
}

- (void)updateConstraints
{
    // Take the height of the table frame and make it so only whole results are displayed
    NSUInteger maxRows = floor(self.frame.size.height / RowHeight);
    
    if (maxRows < 1) {
        maxRows = 1;
    }    
    
    if (self.searchResults.count > maxRows) {
        self.heightConstraint.constant = maxRows * RowHeight;        
    } else {
        self.heightConstraint.constant = self.searchResults.count * RowHeight;
    }
    
    [super updateConstraints];
}

- (void)keyboardDidChangeFrame:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [self setNeedsUpdateConstraints];
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self layoutIfNeeded];
    }];
}

- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    [self setNeedsUpdateConstraints];
}

#pragma mark - Public methods

- (void)showSuggestionsForWord:(NSString *)word
{
    if ([word hasPrefix:@"@"]) {
        self.searchText = [word substringFromIndex:1];
        if (self.searchText.length > 0) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"(displayName contains[c] %@) OR (userLogin contains[c] %@)",
                                            self.searchText, self.searchText];
            self.searchResults = [[self.suggestions filteredArrayUsingPredicate:resultPredicate] mutableCopy];
        } else {
            self.searchResults = [self.suggestions mutableCopy];
        }
    } else {
        self.searchText = @"";
        [self.searchResults removeAllObjects];
    }
    
    [self.tableView reloadData];
    [self setNeedsUpdateConstraints];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (!self.suggestions) {
        return 1;
    }
    
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SuggestionsTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier
                                                                forIndexPath:indexPath];
    
    if (!self.suggestions) {
        cell.usernameLabel.text = NSLocalizedString(@"Loading...", @"Suggestions loading message");
        cell.displayNameLabel.text = nil;
        [cell.avatarImageView setImage:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    
    Suggestion *suggestion = [self.searchResults objectAtIndex:indexPath.row];
    
    cell.usernameLabel.text = [NSString stringWithFormat:@"@%@", suggestion.userLogin];
    cell.displayNameLabel.text = suggestion.displayName;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    [self setAvatarForSuggestion:suggestion forCell:cell indexPath:indexPath];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Suggestion *suggestion = [self.searchResults objectAtIndex:indexPath.row];
    [self.suggestionsDelegate didSelectSuggestion:suggestion.userLogin forSearchText:self.searchText];    
}

#pragma mark - Suggestion list management

- (void)suggestionListUpdated:(NSNotification *)notification
{
    // only reload if the suggestion list is updated for the current site
    if ([notification.object isEqualToNumber:self.siteID]) {
        self.suggestions = [[SuggestionService shared] suggestionsForSiteID:self.siteID];
        [self showSuggestionsForWord:self.searchText];
    }
}

- (NSArray *)suggestions
{
    if (!_suggestions) {
        _suggestions = [[SuggestionService shared] suggestionsForSiteID:self.siteID];
    }
    return _suggestions;
}

#pragma mark - Avatar helper

- (void)setAvatarForSuggestion:(Suggestion *)post forCell:(SuggestionsTableViewCell *)cell indexPath:(NSIndexPath *)indexPath
{
    CGSize imageSize = CGSizeMake(SuggestionsTableViewCellAvatarSize, SuggestionsTableViewCellAvatarSize);
    UIImage *image = [post cachedAvatarWithSize:imageSize];
    if (image) {
        [cell.avatarImageView setImage:image];
    } else {
        [cell.avatarImageView setImage:[UIImage imageNamed:@"gravatar"]];
        [post fetchAvatarWithSize:imageSize success:^(UIImage *image) {
            if (!image) {
                return;
            }
            if (cell == [self.tableView cellForRowAtIndexPath:indexPath]) {
                [cell.avatarImageView setImage:image];
            }
        }];
    }
}

@end
