//
//  WeiTalkListViewController.m
//  iphoneduiai
//
//  Created by Cloud Dai on 12-9-8.
//  Copyright (c) 2012年 duiai.com. All rights reserved.
//

#import "WeiTalkListViewController.h"
#import "Utils.h"
#import <RestKit/RestKit.h>
#import <RestKit/JSONKit.h>
#import "SVProgressHUD.h"
#import "WeiyuWordCell.h"
#import "CustomBarButtonItem.h"
#import "EGORefreshTableHeaderView.h"
#import "AddWeiyuViewController.h"
#import "DropMenuView.h"
#import "CommentViewController.h"
#import "ShowCommentViewController.h"
#import "UserDetailViewController.h"
#import "DetailWeiyuViewController.h"

#import "WeiyuContentCell.h"
#import "WeiyuFaqCell.h"
#import "WeiyuTextPicCell.h"
#import "WeiyuOnePicCell.h"
#import "WeiyuTwoAndMorePicCell.h"

@interface WeiTalkListViewController () <CustomCellDelegate, EGORefreshTableHeaderDelegate, DropMenuViewDataSource, DropMenuViewDelegate>
{
    BOOL reloading;
}

@property (strong, nonatomic) NSMutableArray *weiyus;
@property (strong, nonatomic) UITableViewCell *moreCell;
@property (nonatomic) NSInteger curPage, totalPage;
@property (nonatomic) BOOL loading;
@property (strong, nonatomic) EGORefreshTableHeaderView *refreshHeaderView;
@property (nonatomic) BOOL onlyPhoto;
@property (retain, nonatomic) IBOutlet DropMenuView *dropMenuView;
@property (strong, nonatomic) NSString *city, *selectedSex;
@property (strong, nonatomic) NSString *citySex;
@property (strong, nonatomic) NSArray *filterEntries;
@property (strong, nonatomic) UIButton *tilteBtn;
@property (strong, nonatomic) NSMutableArray *digoList, *shitList;

@end

@implementation WeiTalkListViewController

- (void)dealloc
{
    self.refreshHeaderView.delegate = nil;
    [_weiyus release];
    [_moreCell release];
    [_refreshHeaderView release];
    [_dropMenuView release];
    [_city release];
    [_selectedSex release];
    [_citySex release];
    [_filterEntries release];
    [_tilteBtn release];
    [_digoList release];
    [_shitList release];
    [super dealloc];
}

- (NSMutableArray *)digoList
{
    if (_digoList == nil) {
        _digoList = [[NSMutableArray alloc] init];
    }
    
    return _digoList;
}

- (NSMutableArray *)shitList
{
    if (_shitList == nil) {
        _shitList = [[NSMutableArray alloc] init];
    }
    
    return _shitList;
}

- (NSArray *)filterEntries
{
    if (_filterEntries == nil) {
        _filterEntries = [[NSArray alloc] initWithArray:@[@{@"tag":@"all_w", @"name":@"全部女生"},
                          @{@"tag":@"province_w", @"name":@"同省女生"},
                          @{@"tag":@"city_w", @"name":@"同城女生"},
                          @{@"tag":@"all_m", @"name":@"全部男生"},
                          @{@"tag":@"province_m", @"name":@"同省男生"},
                          @{@"tag":@"city_m", @"name":@"同城男生"}]];
    }
    
    return _filterEntries;
}

- (void)setCitySex:(NSString *)citySex
{
    if (![_citySex isEqualToString:citySex]) {
        _citySex = [citySex retain];
        
        NSArray *tags = [citySex componentsSeparatedByString:@"_"];
        self.selectedSex = [tags objectAtIndex:1];
        self.city = [tags objectAtIndex:0];
        
        NSString *name = nil;
        for (NSDictionary *d in self.filterEntries) {
            if ([[d objectForKey:@"tag"] isEqualToString:citySex]) {
                name = [d objectForKey:@"name"];
                break;
            }
            
        }
        
        [self.tilteBtn setTitle:name forState:UIControlStateNormal];
        [self.tilteBtn setTitle:name forState:UIControlStateHighlighted];
        
        [self reloadList];
    }
}

- (void)setWeiyus:(NSMutableArray *)weiyus
{
    if (![_weiyus isEqualToArray:weiyus]) {
        if (self.curPage > 1) {
            [_weiyus addObjectsFromArray:weiyus];
        } else{
            _weiyus = [[NSMutableArray alloc] initWithArray:weiyus];
        }
        
        [self.tableView reloadData];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg.png"]];
    self.navigationItem.leftBarButtonItem = [[[CustomBarButtonItem alloc] initRightBarButtonWithTitle:@"只看图片"
                                                                                               target:self
                                                                                               action:@selector(exchangeAction:)] autorelease];

    self.navigationItem.rightBarButtonItem = [[[CustomBarButtonItem alloc] initBarButtonWithImage:[UIImage imageNamed:@"weiyu_add_content"]
                                                                                           target:self
                                                                                           action:@selector(addAction)] autorelease];
    
    if (self.refreshHeaderView == nil) {
		
		self.refreshHeaderView = [[[EGORefreshTableHeaderView alloc]
                                  initWithFrame:CGRectMake(0.0f,
                                                           0.0f - self.tableView.bounds.size.height,
                                                           self.view.frame.size.width,
                                                           self.tableView.bounds.size.height)] autorelease];
		self.refreshHeaderView.delegate = self;
        self.refreshHeaderView.backgroundColor = [UIColor clearColor];
        self.refreshHeaderView.opaque = YES;
		[self.tableView addSubview:self.refreshHeaderView];
		
	}
    
	//  update the last update date
	[self.refreshHeaderView refreshLastUpdatedDate];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 100, 44);
    [btn setImage:[UIImage imageNamed:@"arrow_icon"] forState:UIControlStateNormal];
    [btn setImage:[UIImage imageNamed:@"arrow_icon_linked"] forState:UIControlStateHighlighted];
    btn.titleEdgeInsets = UIEdgeInsetsMake(0, -15, 0, 0);
    btn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -160);
    btn.titleLabel.shadowOffset = CGSizeMake(0.0, 1);
    [btn setTitleShadowColor:RGBCOLOR(120, 200, 235) forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(selectAeraAction:) forControlEvents:UIControlEventTouchUpInside];
    [btn setTitleColor:RGBCOLOR(232, 247, 253) forState:UIControlStateHighlighted];
    self.navigationItem.titleView = btn;
    self.tilteBtn = btn;
}

- (void)selectAeraAction:(UIButton*)btn
{
    CGRect posFrame = [self.navigationItem.titleView.superview convertRect:self.navigationItem.titleView.frame toView:self.view.window];
    [self.dropMenuView showMeAtView:self.view
                            atPoint:CGPointMake((320-self.dropMenuView.frame.size.width)/2, posFrame.origin.y+posFrame.size.height)
                           animated:YES];

}

- (void)exchangeAction:(CustomBarButtonItem*)item
{
    // here dou
    if (self.tableView.isDecelerating ||
        self.tableView.isDragging ||
        self.tableView.isEditing) {
        return;
    }
    if (self.onlyPhoto) {
        self.onlyPhoto = NO;
        self.navigationItem.leftBarButtonItem = [[[CustomBarButtonItem alloc] initRightBarButtonWithTitle:@"只看图片"
                                                                                                   target:self
                                                                                                   action:@selector(exchangeAction:)] autorelease];
    } else{
        self.onlyPhoto = YES;
        self.navigationItem.leftBarButtonItem = [[[CustomBarButtonItem alloc] initRightBarButtonWithTitle:@"查看全部"
                                                                                                   target:self
                                                                                                   action:@selector(exchangeAction:)] autorelease];
    }
    
    [self reloadList];
}

- (void)addAction
{

    AddWeiyuViewController *awvc = [[AddWeiyuViewController alloc] initWithNibName:@"AddWeiyuViewController" bundle:nil];
    [self.navigationController pushViewController:awvc animated:YES];
    [awvc release];
}

- (void)viewDidUnload
{
    [self setDropMenuView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [MobClick beginLogPageView:NSStringFromClass([self class])];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [MobClick endLogPageView:NSStringFromClass([self class])];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.weiyus.count <= 0) {

        NSDictionary *info = [[[NSUserDefaults standardUserDefaults] objectForKey:@"user"] objectForKey:@"info"];
        if ([info[@"sex"] isEqualToString:@"m"]) {
            self.citySex = @"city_w";
        } else{
            self.citySex = @"city_m";
        }
    }
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (self.totalPage <= self.curPage) {
        return self.weiyus.count;
    } else{
        return self.weiyus.count + 1;
    }
    
}

-(UITableViewCell *)createMoreCell:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"moretag"] autorelease];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	UILabel *labelNumber = [[UILabel alloc] initWithFrame:CGRectMake(110, 10, 100, 20)];
    labelNumber.textAlignment = UITextAlignmentCenter;
    
    if (self.totalPage <= self.curPage){
        labelNumber.text = @"";
    } else {
        labelNumber.text = @"更多";
    }
    
	[labelNumber setTag:1];
	labelNumber.backgroundColor = [UIColor clearColor];
	labelNumber.font = [UIFont boldSystemFontOfSize:18];
	[cell.contentView addSubview:labelNumber];
	[labelNumber release];
	
    self.moreCell = cell;
    
    return self.moreCell;
}

- (UITableViewCell *)creatNormalCell:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    NSMutableDictionary *weiyu = self.weiyus[indexPath.row];
    if ([weiyu[@"vtype"] isEqualToString:@"photo"])
    {
        
        if(1 < [weiyu[@"photolist"] count] && 4 > [weiyu[@"photolist"] count])
        {
            static NSString *CellIdentifier = @"WeiyuThreeCell";
            [tableView registerNib:[UINib nibWithNibName:@"WeiyuThreeCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
            WeiyuTwoAndMorePicCell  *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            cell.delegate = self;         
            cell.weiyu = weiyu;
            
            return cell;
        }
        else if(4 == [weiyu[@"photolist"] count])
        {
            static NSString *CellIdentifier = @"WeiyuFourCell";
            [tableView registerNib:[UINib nibWithNibName:@"WeiyuFourCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
            WeiyuTwoAndMorePicCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            cell.delegate = self;
            
            cell.weiyu = weiyu;
            
            return cell;
        }
        else if(4 < [weiyu[@"photolist"] count] && 7 > [weiyu[@"photolist"] count])
        {
            static NSString *CellIdentifier = @"WeiyuSixCell";
            [tableView registerNib:[UINib nibWithNibName:@"WeiyuSixCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
            WeiyuTwoAndMorePicCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            cell.delegate= self;
            
            cell.weiyu = weiyu;
            
            return cell;
        }
        else if(6 < [weiyu[@"photolist"] count] && 10 > [weiyu[@"photolist"] count])
        {
            static NSString *CellIdentifier = @"WeiyuNineCell";
            [tableView registerNib:[UINib nibWithNibName:@"WeiyuNineCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
            WeiyuTwoAndMorePicCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            cell.delegate = self;
            
            cell.weiyu = weiyu;
            
            return cell;
        } else {
            static NSString *CellIdentifier = @"WeiyuOnePicCell";
            [tableView registerNib:[UINib nibWithNibName:@"WeiyuOnePicCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
            WeiyuOnePicCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            cell.delegate = self;
            
            cell.weiyu = weiyu;
            
            return cell;
        }
        
    }
    else if ([weiyu[@"vtype"] isEqualToString:@"textpic"])
    {
        static NSString *CellIdentifier = @"WeiyuTextPicCell";
        [tableView registerNib:[UINib nibWithNibName:@"WeiyuTextPicCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
        WeiyuTextPicCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        cell.delegate = self;
        
        cell.weiyu = weiyu;
        
        return cell;
    }
    else if ([weiyu[@"vtype"] isEqualToString:@"faq"])
    {
        static NSString *CellIdentifier = @"WeiyuFaqCell";
        [tableView registerNib:[UINib nibWithNibName:@"WeiyuFaqCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
        WeiyuFaqCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        cell.delegate = self;
        
        cell.weiyu = weiyu;
        
        return cell;
    }
    else
    {
        static NSString *CellIdentifier = @"WeiyuContentCell";
        [tableView registerNib:[UINib nibWithNibName:@"WeiyuContentCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];
        WeiyuContentCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        cell.delegate = self;
        
        cell.weiyu = weiyu;
        
        return cell;
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == self.weiyus.count) {
        return [self createMoreCell:tableView cellForRowAtIndexPath:indexPath];
    }else {
        return [self creatNormalCell:tableView cellForRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == self.weiyus.count) {
        
        return 40.0f;
    }else {
        WeiyuWordCell *cell = (WeiyuWordCell *)[self creatNormalCell:tableView cellForRowAtIndexPath:indexPath];
        return [cell requiredHeight];
        
    }
}

- (void)loadNextInfoList
{
    UILabel *label = (UILabel*)[self.moreCell.contentView viewWithTag:1];
    label.text = @"正在加载..."; // bug no reload table not show it.
    
    if (!self.loading) {
        [self grabWeiyuListReqeustWithPage:self.curPage+1];
        self.loading = YES;
    }
    
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == self.weiyus.count) {
        double delayInSeconds = 0.3;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self loadNextInfoList];
        });
    }
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 20)] autorelease];
    view.backgroundColor = [UIColor clearColor];
    view.opaque = YES;
    
    return view;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
 
    self.tableView.sectionHeaderHeight = 20.0f;
    return 20.0f;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  
    CGFloat sectionHeaderHeight = self.tableView.sectionHeaderHeight; // note: the height is static.
    
    if (scrollView.contentOffset.y <= sectionHeaderHeight &&
        scrollView.contentOffset.y>=0) {
        
        scrollView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
        
    } else if (scrollView.contentOffset.y >= sectionHeaderHeight) {
        
        scrollView.contentInset = UIEdgeInsetsMake(-sectionHeaderHeight, 0, 0, 0);
        
    }
    [self.refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];

}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    
    [self.refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
    
}

#pragma mark Data Source Loading / Reloading Methods

- (void)reloadTableViewDataSource
{
    
    //  should be calling your tableviews data source model to reload

    [self grabWeiyuListReqeustWithPage:1];
    
    reloading = YES;
    
}

- (void)doneLoadingTableViewData
{
    
    //  model should call this when its done loading
    reloading = NO;
    [self.refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
    
}

#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
    
    [self reloadTableViewDataSource];
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self doneLoadingTableViewData];
    });
    
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{
    
    return reloading; // should return if data source model is reloading
    
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view
{
    
    return [NSDate date]; // should return date data source was last changed
    
}

-(void)reloadList
{
    
    [UIView animateWithDuration:0.3f animations:^{
        
        self.tableView.contentOffset = CGPointMake(0, -65);
        
    } completion:^(BOOL finished) {
        
        [self.refreshHeaderView egoRefreshScrollViewDidEndDragging:self.tableView];
        
    }];
}


#pragma mark requests
- (void)grabWeiyuListReqeustWithPage:(NSInteger)page
{
    NSMutableDictionary *dParams = [Utils queryParams];
    
    if (self.onlyPhoto) {
        [dParams setObject:@"photo" forKey:@"a"];
    }
    dParams[@"gmd"] = @"uc";
//    NSDictionary *info = [[[NSUserDefaults standardUserDefaults] objectForKey:@"user"] objectForKey:@"info"];

    [dParams setObject:self.selectedSex forKey:@"sex"];
    [dParams setObject:self.city forKey:@"city"];
    [dParams setObject:[NSNumber numberWithInteger:page] forKey:@"page"];
    [dParams setObject:@"20" forKey:@"pagesize"];
    
    [[RKClient sharedClient] get:[@"/v" stringByAppendingQueryParameters:dParams] usingBlock:^(RKRequest *request){
        [request setOnDidLoadResponse:^(RKResponse *response){
            if (response.isOK && response.isJSON) {
                NSMutableDictionary *data = [[response bodyAsString] mutableObjectFromJSONString];
//                NSLog(@"weiyu list data: %@", data);
                NSInteger code = [data[@"error"] integerValue];
//                NSLog(@"%@",data);
                if (code == 0) {
                    self.loading = NO;
                    self.totalPage = [[[data objectForKey:@"pager"] objectForKey:@"pagecount"] integerValue];
                    self.curPage = [[[data objectForKey:@"pager"] objectForKey:@"thispage"] integerValue];
                    // 此行须在前两行后面
                    self.weiyus = [data objectForKey:@"data"];
                    [self.refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
                } else{
                    [SVProgressHUD showErrorWithStatus:data[@"message"]];
                }
 
            }
        }];
        
        [request setOnDidFailLoadWithError:^(NSError *error){
            NSLog(@"error: %@", [error description]);
        }];
        
    }];
}

- (void)digoWeiyu:(NSMutableDictionary*)weiyu cell:(WeiyuWordCell*)cell shit:(BOOL)isShit
{
    NSMutableDictionary *params = [Utils queryParams];

    [SVProgressHUD show];
    [[RKClient sharedClient] post:[@"/v/digo.api" stringByAppendingQueryParameters:params] usingBlock:^(RKRequest *request){
//        NSLog(@"url: %@", request.URL);
        
        request.params = [RKParams paramsWithDictionary:@{@"id" : weiyu[@"id"], @"shit": @(isShit), @"submitupdate": @"true"}];
        
        [request setOnDidLoadResponse:^(RKResponse *response){
            
            if (response.isOK && response.isJSON) {
                NSDictionary *data = [[response bodyAsString] objectFromJSONString];
                //                        NSLog(@"read data: %@", data[@"message"]);
                NSInteger code = [data[@"error"] integerValue];
                if (code == 0) {
                    if (isShit) {

                        cell.shitNum += 1;
                        [self.shitList addObject:weiyu[@"id"]];
                    } else{
                        if ([self.digoList containsObject:weiyu[@"id"]]) {
                            [self.digoList removeObject:weiyu[@"id"]];
                            cell.digoNum -= 1;
                        } else{
                            [self.digoList addObject:weiyu[@"id"]];
                            cell.digoNum += 1;
                        }

                    }
                    
                    [SVProgressHUD dismiss];
                } else{
                    [SVProgressHUD showErrorWithStatus:data[@"message"]];
                }
                
            } else{
                [SVProgressHUD showErrorWithStatus:@"获取失败"];
            }
        }];
        [request setOnDidFailLoadWithError:^(NSError *error){
            [SVProgressHUD showErrorWithStatus:@"网络连接错误"];
            NSLog(@"Error: %@", [error description]);
        }];
    }];
}


#pragma mark - cell delegate
- (void)didChangeStatus:(UITableViewCell *)cell toStatus:(NSString *)status
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];

//    NSLog(@"status: %@", status);
    NSMutableDictionary *weiyu = self.weiyus[indexPath.row];
//    NSString *idStr = weiyu[@"id"];
    if ([status isEqualToString:@"comment"]) {
        
        ShowCommentViewController *showCommentViewController = [[ShowCommentViewController alloc]initWithNibName:@"ShowCommentViewController" bundle:nil];
        showCommentViewController.weiYuDic = weiyu;
        [self.navigationController pushViewController:showCommentViewController animated:YES];
        [showCommentViewController release];
        
    } else if ([status isEqualToString:@"minus"]){
        // minus
        if (![self.shitList containsObject:weiyu[@"id"]]) {
            [self digoWeiyu:weiyu cell:(WeiyuWordCell*)cell shit:YES];
        }

    } else if ([status isEqualToString:@"plus"]){
        // plus

        [self digoWeiyu:weiyu cell:(WeiyuWordCell*)cell shit:NO];

        
    } else if ([status isEqualToString:@"tap_avatar"]){
        UserDetailViewController *udvc = [[UserDetailViewController alloc] initWithNibName:@"UserDetailViewController" bundle:nil];
        udvc.user = @{@"_id": weiyu[@"uid"], @"niname": weiyu[@"uinfo"][@"niname"], @"photo": weiyu[@"uinfo"][@"photo"]};
        [self.navigationController pushViewController:udvc animated:YES];
        [udvc release];
    }    
}

#pragma mark - drop menu 
- (NSArray *)dropMenuViewData:(DropMenuView *)dropView
{
    return self.filterEntries;

}

- (void)didSelectedMenuCell:(DropMenuView *)dropView withTag:(NSString *)tag name:(NSString *)name
{
    
    if (self.tableView.isDecelerating ||
        self.tableView.isDragging ||
        self.tableView.isEditing) {
        return;
    }
    
    self.citySex = tag;

}

@end
