//
//  SampleWKWebViewController.swift
//

import UIKit
import WebKit
import TabPageViewController

class SampleWKWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler{
    
    // AppDelegate
    var appDelegate:AppDelegate!
    
    // 各サイズ
    var deviceWidth:CGFloat = 0
    var deviceHeight:CGFloat = 0
    var statusbarHeight:CGFloat = 0.0
    var navBarHeight:CGFloat = 0.0
    var tabHeight: CGFloat = 0.0
    
    // 通信可不可をチェックするクラスのインスタンス
    var reachability: AMReachability!
    
    // 各変数
    var tabPageViewController = TabPageViewController()
    var baseViewController = BaseViewController()
    var webView: WKWebView!
    var reloadView: UIView!
    var reloadButton: UIButton!
    var loadingView: UIView!
    var loadingLabel: UILabel!
    var loadingIndicator: UIActivityIndicatorView!
    var refreshControl:UIRefreshControl!
    var timerCommitWebView:NSTimer = NSTimer()
    var url:String = ""
    var nsUrl:NSURL!
    var urlRequest:NSURLRequest!
    var isWebViewLinkTapped: Bool!
    var detailUrl:String = ""
    var trans:UIViewAnimationTransition!
    
    // アプリ起動時初回に一度のみ呼ばれる
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ページ背景白
        self.view.backgroundColor = UIColor.whiteColor()
        
        //AppDelegateインスタンス生成
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        // 各サイズ格納
        deviceWidth = appDelegate.deviceWidth
        deviceHeight = appDelegate.deviceHeight
        statusbarHeight = appDelegate.statusbarHeight
        navBarHeight = appDelegate.navBarHeight
        tabHeight = appDelegate.tabHeight
        
        // 通信可不可をチェックするクラスのインスタンスをappDelegateから受け取る
        reachability = appDelegate.reachability
        
        // WebView生成
        createWebView()
        
        // 接続不可時の画面作成
        createReloadView()
        
        // 読み込み中の画面作成
        createLoadingView()
        
        // メニューボタン押下有無初期化
        appDelegate.isMenuButtonTapped = false
        
        // ログイン、マイページ押下有無初期化
        appDelegate.isLoginMypageButtonTapped = false
        
        // ログイン有無
        appDelegate.isLogin = false
    }
    
    // 画面が表示される直前に呼ばれる
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // AppDelegateからフォアグラウンドやバックグラウンドが通知されるメソッドの登録
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "viewWillEnterForeground:", name: "applicationWillEnterForeground", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "viewDidEnterBackground:", name: "applicationDidEnterBackground", object: nil)
    }
    
    // 画面が表示された直後とモーダルから戻ってきた時に呼ばれる
    override func viewDidAppear(animated: Bool) {
        if (appDelegate.isMenuButtonTapped == false &&
            appDelegate.isLoginMypageButtonTapped == false &&
            isWebViewLinkTapped == false) {
            // 接続試行
            doConnection()
        } else {
            appDelegate.isMenuButtonTapped = false
            appDelegate.isLoginMypageButtonTapped = false
            isWebViewLinkTapped = false
        }
    }
    
    // 別の画面に遷移する直前に呼ばれる
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //////////以上iOSライフサイクル//////////
    
    // AppDelegateからフォアグラウンドの通知
    func viewWillEnterForeground(notification: NSNotification?) {
        print("フォアグラウンド")
        // 接続試行
        doConnection()
    }
    
    // AppDelegateからバックグラウンドの通知
    func viewDidEnterBackground(notification: NSNotification?) {
        print("バックグラウンド")
        // 引っ張って更新のぐるぐるを非表示
        refreshControl.endRefreshing()
        
        // ページ読み込み後や接続不可時の処理
        didFinishConnection()
    }
    
    // WebViewを生成する
    func createWebView(){
        
        // JavaScriptから値を受け取るための設定
        let webCfg:WKWebViewConfiguration = WKWebViewConfiguration()
        let userController:WKUserContentController = WKUserContentController()
        userController.addScriptMessageHandler(self, name: "callbackHandler")
        webCfg.userContentController = userController;
        
        //webView生成
        webView = WKWebView(frame: CGRectMake(0, statusbarHeight + navBarHeight + tabHeight, deviceWidth, deviceHeight - (statusbarHeight + navBarHeight + tabHeight)),configuration: webCfg)
        webView.navigationDelegate = self
        self.view.addSubview(webView!)
        webView.hidden = true
        
        // 引っ張って更新生成
        refreshControl = UIRefreshControl()
        refreshControl?.attributedTitle = NSAttributedString(string: "引っ張って更新")
        refreshControl?.addTarget(self, action: #selector(ViewController.doConnection), forControlEvents: UIControlEvents.ValueChanged)
        webView.scrollView.addSubview(refreshControl)
        
        // webView内のリンクをタップ有無初期化
        isWebViewLinkTapped = false
    }
    
    // 接続不可時の画面作成
    func createReloadView() {
        
        // 更新ボタンを置く画面を生成
        reloadView = UIView(frame: CGRectMake(0, statusbarHeight + navBarHeight + tabHeight, deviceWidth, deviceHeight - (statusbarHeight + navBarHeight + tabHeight)))
        reloadView.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(reloadView)
        reloadView.hidden = true
        
        // 更新ボタン生成
        reloadButton = UIButton(type: UIButtonType.Custom)
        reloadButton.setImage(UIImage(named: "images/icon_reload.png"), forState: UIControlState.Normal)
        reloadButton.addTarget(self, action: #selector(self.onClickReload), forControlEvents: UIControlEvents.TouchUpInside)
        let posX = (deviceWidth / 2) - ((navBarHeight * 0.8) / 2)
        let posY = (reloadView.frame.height / 2) - ((navBarHeight * 0.8) / 2)
        reloadButton.frame = CGRectMake(posX, posY, navBarHeight * 0.8, navBarHeight * 0.8)
        reloadView.addSubview(reloadButton)
    }
    
    // 読み込み中の画面作成
    func createLoadingView() {
        
        // 読み込み中ラベルを置く画面を生成
        loadingView = UIView(frame: CGRectMake(0, statusbarHeight + navBarHeight + tabHeight, deviceWidth, deviceHeight - (statusbarHeight + navBarHeight + tabHeight)))
        loadingView.backgroundColor = UIColor.clearColor()
        self.view.addSubview(loadingView)
        loadingView.hidden = true
        
        // インジケーター
        loadingIndicator = UIActivityIndicatorView()
        let loadingIndicatorWidthHeight:CGFloat = 50.0
        let posX = (deviceWidth / 2) - (loadingIndicatorWidthHeight / 2)
        let posY = (loadingView.frame.height / 2) - (loadingIndicatorWidthHeight / 2)
        loadingIndicator.frame = CGRectMake(posX, posY, loadingIndicatorWidthHeight, loadingIndicatorWidthHeight)
        loadingIndicator.hidesWhenStopped = false
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.White
        loadingIndicator.backgroundColor = UIColor.grayColor()
        loadingIndicator.layer.masksToBounds = true
        loadingIndicator.layer.cornerRadius = 5.0
        loadingIndicator.layer.opacity = 0.8
        loadingView.addSubview(loadingIndicator);
    }
    
    // Webページ読み込み
    func loadWebView(){
        nsUrl = NSURL(string: url)
        let urlRequest = NSURLRequest(URL: nsUrl!)
        webView.loadRequest(urlRequest)
    }
    
    // 接続試行
    func doConnection(){
        
        // インターネット接続可不可判定
        if reachability.isReachable() {
            // インターネット接続可
            // インジケータ(画面左上の小さなグルグル)表示
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            // Webページ読み込み
            loadWebView()
            
            webView.hidden = false
            reloadView.hidden = true
            
        } else {
            // インターネット接続不可
            // ページ読み込み後の処理
            didFinishConnection()
            
            webView.hidden = true
            reloadView.hidden = false
        }
    }
    
    // ページ読み込み後の処理
    func didFinishConnection() {
        
        // 引っ張って更新のぐるぐる表示を非表示
        refreshControl.endRefreshing()
        
        // インジケータ(画面左上の小さなグルグル)非表示
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        
        // baseViewControllerへ通知。更新中を非表示
        baseViewController.didFinishConnection()
    }
    
    // ページの読み込みが開始時に呼ばれる
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!){
        // 引っ張って更新のぐるぐるを非表示
        refreshControl.endRefreshing()
        
        // 特定のページはローディング表示しない
        if (url.containsString(CONST_KURASHINISTA_URL + "articles/index") ||
            url.containsString(CONST_KURASHINISTA_URL + "articles/?sort=new")) {
            
            // ローディング非表示
            self.loadingView.hidden = true
            
        } else {
            // タイマーで特定秒数後にローディング表示開始
            let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64( 0.7 * Double(NSEC_PER_SEC)))
            dispatch_after( dispatchTime, dispatch_get_main_queue(), {
                
                // ローディング表示
                self.loadingView.hidden = false
                
            } );
        }
    }
    
    // ページが見つかり、そのページを読み込み開始時に呼ばれる
    func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
        // ローディング非表示
        loadingView.hidden = true
    }
    
    // ページの読み込みが完了時に呼ばれる
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!){
        // ローディング非表示
        loadingView.hidden = true
        
        // ページ読み込み後や接続不可時の処理
        didFinishConnection()
    }
    
    // ページ読み込み失敗
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation, withError error: NSError) {
        // ローディング非表示
        loadingView.hidden = true
        
        // ページ読み込み後や接続不可時の処理
        didFinishConnection()
    }
    
    // ページ読み込み失敗
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: NSError) {
        // ローディング非表示
        loadingView.hidden = true
        
        // ページ読み込み後や接続不可時の処理
        didFinishConnection()
    }
    
    // 読み込んだページ内のリンク情報など取得
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        
        // リンクタップした時
        if(navigationAction.navigationType == WKNavigationType.LinkActivated) {
            // webView内のリンクタップした
            isWebViewLinkTapped = true
            
            // 詳細画面をモーダルで開いて遷移
            let detailViewController = DetailViewController()
            detailViewController.url = navigationAction.request.URL!.absoluteString
            self.navigationController?.pushViewController(detailViewController, animated: true)
            
            // webView内でのページ遷移を禁止
            decisionHandler(WKNavigationActionPolicy.Cancel)
        }
        
        // webView内でのページ遷移を許可(これを実装していないとアプリが落ちる)
        decisionHandler(WKNavigationActionPolicy.Allow)
    }
    
    // JavaScriptからJSONで値を受け取る
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if(message.name == "callbackHandler") {
            // json受け取り
            let jsonData = message.body as! NSDictionary
            
            // ログイン有無取得
            if (jsonData["is_login"]! as! NSObject == 0) {
                appDelegate.isLogin = false
            } else {
                appDelegate.isLogin = true
            }
        }
    }
    
    // 証明書処理
    func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge,
                 completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        switch (challenge.protectionSpace.authenticationMethod) {
        // ベーシック認証
        case NSURLAuthenticationMethodHTTPBasic:
            let credential = NSURLCredential(user: "user", password: "password", persistence: NSURLCredentialPersistence.ForSession)
            completionHandler(.UseCredential, credential)
            
        default:
            completionHandler(.RejectProtectionSpace, nil);
        }
    }
    
    // 更新ボタンを押した時のアクション
    func onClickReload() {
        // 接続試行
        doConnection()
    }
}

