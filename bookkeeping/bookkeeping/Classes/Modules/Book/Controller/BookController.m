/**
 * 记账
 * @author 郑业强 2018-12-16 创建文件
 */

#import "BookController.h"
#import "BookCollectionView.h"
#import "BookNavigation.h"
#import "BookKeyboard.h"
#import "BookListModel.h"
#import "CategoryController.h"
#import "KKRefreshGifHeader.h"
#import "BOOK_EVENT.h"


#pragma mark - 声明
@interface BookController()<UIScrollViewDelegate>

@property (nonatomic, strong) BookNavigation *navigation;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSMutableArray<BookCollectionView *> *collections;
@property (nonatomic, strong) BookKeyboard *keyboard;
@property (nonatomic, strong) NSArray<BookListModel *> *models;
@property (nonatomic, strong) NSDictionary<NSString *, NSInvocation *> *eventStrategy;

@end


#pragma mark - 实现
@implementation BookController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self setJz_navigationBarHidden:YES];
    [self setTitle:@"记账"];
    [self navigation];
    [self scroll];
    [self collections];
    [self keyboard];
    [self getCategoryListRequest];
}


#pragma mark - 点击
- (void)rightButtonClick {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}


#pragma mark - 请求
// 获取我的分类
- (void)getCategoryListRequest {
    @weakify(self)
    [self.scroll createRequest:CategoryListRequest params:@{} complete:^(APPResult *result) {
        @strongify(self)
        [self setModels:[BookListModel mj_objectArrayWithKeyValuesArray:result.data]];
    }];
}
// 记账
- (void)createBookRequest:(NSString *)price mark:(NSString *)mark date:(NSDate *)date {
    NSInteger index = self.scroll.contentOffset.x / SCREEN_WIDTH;
    BookCollectionView *collection = self.collections[index];
    BookModel *model = collection.model.list[collection.selectIndex.row];
    NSMutableDictionary *param = ({
        NSMutableDictionary *param = [NSMutableDictionary dictionary];
        [param setObject:price forKey:@"price"];
        if (model.is_system) {
            [param setObject:@(model.Id) forKey:@"category_id"];
        } else {
            [param setObject:@(model.Id) forKey:@"insert_id"];
        }
        [param setObject:@(model.is_income) forKey:@"is_income"];
        [param setObject:@(date.year) forKey:@"year"];
        [param setObject:@(date.month) forKey:@"month"];
        [param setObject:@(date.day) forKey:@"day"];
        [param setObject:mark forKey:@"mark"];
        param;
    });
    @weakify(self)
    [self showProgressHUD:@"记账中"];
    [AFNManager POST:CreateBookRequest params:param complete:^(APPResult *result) {
        @strongify(self)
        [self hideHUD];
        if (result.status == ServiceCodeSuccess) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NOT_BOOK_COMPLETE object:nil];
            [self.navigationController dismissViewControllerAnimated:true completion:nil];
        } else {
            [self showTextHUD:result.message delay:1.f];
        }
    }];
}



#pragma mark - set
- (void)setModels:(NSArray<BookListModel *> *)models {
    _models = models;
    for (int i=0; i<models.count; i++) {
        self.collections[i].model = models[i];
    }
}


#pragma mark - 事件
- (void)routerEventWithName:(NSString *)eventName data:(id)data {
    [self handleEventWithName:eventName data:data];
}
- (void)handleEventWithName:(NSString *)eventName data:(id)data {
    NSInvocation *invocation = self.eventStrategy[eventName];
    [invocation setArgument:&data atIndex:2];
    [invocation invoke];
    [super routerEventWithName:eventName data:data];
}
// 点击导航栏
- (void)bookClickNavigation:(NSNumber *)index {
    [self.scroll setContentOffset:CGPointMake(SCREEN_WIDTH * [index integerValue], 0) animated:YES];
}
// 点击item
- (void)bookClickItem:(BookCollectionView *)collection {
    NSIndexPath *indexPath = collection.selectIndex;
    BookListModel *listModel = _models[collection.tag];
    // 选择类别
    if (indexPath.row != (listModel.list.count - 1)) {
        // 显示键盘
        [self.keyboard show];
        // 刷新
        NSInteger page = _scroll.contentOffset.x / SCREEN_WIDTH;
        BookCollectionView *collection = self.collections[page];
        [collection setHeight:SCREEN_HEIGHT - NavigationBarHeight - self.keyboard.height];
        [collection scrollToIndex:indexPath];
    }
    // 设置
    else {
        // 隐藏键盘
        for (BookCollectionView *collection in self.collections) {
            [collection reloadSelectIndex];
            [collection setHeight:SCREEN_HEIGHT - NavigationBarHeight];
        }
        [self.keyboard hide];
        // 刷新
        CategoryController *vc = [[CategoryController alloc] init];
        [vc setIs_income:collection.tag];
        [vc setComplete:^{
            [AFNManager POST:CategoryListRequest params:@{} complete:^(APPResult *result) {
                [self setModels:[BookListModel mj_objectArrayWithKeyValuesArray:result.data]];
            }];
        }];
        [self.navigationController pushViewController:vc animated:YES];
    }
}


#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    for (BookCollectionView *collection in self.collections) {
        [collection reloadSelectIndex];
        [collection setHeight:SCREEN_HEIGHT - NavigationBarHeight];
    }
    [self.keyboard hide];
    [self.navigation setOffsetX:scrollView.contentOffset.x];
}


#pragma mark - get
- (UIScrollView *)scroll {
    if (!_scroll) {
        _scroll = [[UIScrollView alloc] initWithFrame:({
            CGFloat left = 0;
            CGFloat top = NavigationBarHeight;
            CGFloat width = SCREEN_WIDTH;
            CGFloat height = SCREEN_HEIGHT - NavigationBarHeight;
            CGRectMake(left, top, width, height);
        })];
        [_scroll setDelegate:self];
        [_scroll setShowsHorizontalScrollIndicator:NO];
        [_scroll setPagingEnabled:YES];
        [self.view addSubview:_scroll];
    }
    return _scroll;
}
- (BookNavigation *)navigation {
    if (!_navigation) {
        _navigation = [BookNavigation loadFirstNib:CGRectMake(0, 0, SCREEN_WIDTH, NavigationBarHeight)];
        [self.view addSubview:_navigation];
    }
    return _navigation;
}
- (NSMutableArray<BookCollectionView *> *)collections {
    if (!_collections) {
        _collections = [NSMutableArray array];
        for (int i=0; i<2; i++) {
            BookCollectionView *collection = [BookCollectionView initWithFrame:({
                CGFloat width = SCREEN_WIDTH;
                CGFloat left = i * width;
                CGFloat height = SCREEN_HEIGHT - NavigationBarHeight;
                CGRectMake(left, 0, width, height);
            })];
            [collection setTag:i];
            [_scroll setContentSize:CGSizeMake(SCREEN_WIDTH * 2, 0)];
            [_scroll addSubview:collection];
            [_collections addObject:collection];
        }
    }
    return _collections;
}
- (BookKeyboard *)keyboard {
    if (!_keyboard) {
        @weakify(self)
        _keyboard = [BookKeyboard init];
        [_keyboard setComplete:^(NSString *price, NSString *mark, NSDate *date) {
            @strongify(self)
            [self createBookRequest:price mark:mark date:date];
        }];
        [self.view addSubview:_keyboard];
    }
    return _keyboard;
}
- (NSDictionary<NSString *, NSInvocation *> *)eventStrategy {
    if (!_eventStrategy) {
        _eventStrategy = @{
                           BOOK_CLICK_ITEM: [self createInvocationWithSelector:@selector(bookClickItem:)],
                           BOOK_CLICK_NAVIGATION: [self createInvocationWithSelector:@selector(bookClickNavigation:)],
                           };
    }
    return _eventStrategy;
}



@end
