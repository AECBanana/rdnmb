import { AnoBBSClient } from "../api/Client";
import { BoardThread, BoardThreadRaw } from "../models/Post";
import { Community, Timeline, Forum } from "../models/Forum";
import { ThreadListItem } from "../components/ThreadListItem";
import { RequiresLoginException } from "../models/Errors";
import { CookieManager } from "../utils/CookieManager";
import { SettingsManager } from "../utils/SettingsManager";
import { PostSheet } from "../components/PostSheet";
import { FavoriteThread } from "../models/FavoriteThread";

interface BoardInfo {
  id: number;
  name: string;
  isTimeline: boolean;
}

@CustomDialog
struct JumpToThreadDialog {
  controller: CustomDialogController;
  @State inputValue: string = "";
  onJump: (threadId: number) => void = () => {};

  parseThreadId(input: string): number | null {
    const trimmed: string = input.trim();
    if (trimmed.length === 0) {
      return null;
    }

    const urlMatch: RegExpMatchArray | null = trimmed.match(/nmbxd\d*\.com\/t\/(\d+)/);
    if (urlMatch !== null && urlMatch.length > 1) {
      return parseInt(urlMatch[1]);
    }

    const noMatch: RegExpMatchArray | null = trimmed.match(/No\.(\d+)/i);
    if (noMatch !== null && noMatch.length > 1) {
      return parseInt(noMatch[1]);
    }

    const numberMatch: RegExpMatchArray | null = trimmed.match(/^(\d+)$/);
    if (numberMatch !== null && numberMatch.length > 1) {
      return parseInt(numberMatch[1]);
    }

    return null;
  }

  build() {
    Column() {
      Text("跳转到串")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })
      Text("输入串ID、No.xxx 或串网址")
        .fontSize(14)
        .fontColor($r("app.color.text_secondary"))
        .margin({ bottom: 16 })
      TextInput({ text: $$this.inputValue, placeholder: "例如: 67818449 或 No.67818449" })
        .width("100%")
        .height(44)
        .margin({ bottom: 16 })
      Row() {
        Button("取消")
          .width("45%")
          .height(40)
          .fontColor($r("app.color.text_primary"))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.controller.close();
          })
        Button("跳转")
          .width("45%")
          .height(40)
          .backgroundColor($r("app.color.primary"))
          .onClick(() => {
            const threadId: number | null = this.parseThreadId(this.inputValue);
            if (threadId !== null && threadId > 0) {
              this.onJump(threadId);
              this.controller.close();
            }
          })
      }
      .width("100%")
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .margin(16)
    .padding(20)
    .backgroundColor($r("app.color.card_background"))
    .borderRadius(16);
  }
}

@Entry
@Component
struct BoardListPage {
  @State threads: BoardThread[] = [];
  @State isLoading: boolean = false;
  @State isLoadingMore: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = "";
  @State currentPage: number = 1;
  @State currentBoardId: number = -1;
  @State currentBoardName: string = "时间线";
  @State isCurrentTimeline: boolean = true;
  @State @Watch("onBoardDrawerChange") showBoardDrawer: boolean = false;
  @State communities: Community[] = [];
  @State timelines: Timeline[] = [];
  @State boardsLoading: boolean = true;
  @State hasMore: boolean = true;
  @State readAnnouncementIds: number[] = [];
  @State showPostSheet: boolean = false;
  @State isShowingFavorites: boolean = false;
  @State favoriteThreads: FavoriteThread[] = [];

  private client: AnoBBSClient = new AnoBBSClient();
  private scroller: Scroller = new Scroller();
  private boardListScroller: Scroller = new Scroller();
  private cookieManager: CookieManager = CookieManager.getInstance();
  private settingsManager: SettingsManager = SettingsManager.getInstance();
  private static readonly ADMIN_ANNOUNCEMENT_THREAD_ID: number = 52752005;
  private static readonly FAVORITES_BOARD_ID: number = -999;
  private jumpToThreadDialogController: CustomDialogController | null = null;

  onBoardDrawerChange(show: boolean): void {
    if (show) {
      setTimeout(() => {
        const index: number = this.getSelectedBoardIndex();
        if (index >= 0) {
          this.boardListScroller.scrollToIndex(index, false, ScrollAlign.CENTER);
        }
      }, 100);
    }
  }

  getSelectedBoardIndex(): number {
    if (this.currentBoardId === BoardListPage.FAVORITES_BOARD_ID) {
      return 1;
    }

    let index: number = 3;

    for (let i: number = 0; i < this.timelines.length; i++) {
      if (this.currentBoardId === -this.timelines[i].id) {
        return index;
      }
      index++;
    }

    for (let i: number = 0; i < this.communities.length; i++) {
      index++;
      for (let j: number = 0; j < this.communities[i].forums.length; j++) {
        if (this.currentBoardId === this.communities[i].forums[j].id) {
          return index;
        }
        index++;
      }
    }

    return -1;
  }

  async aboutToAppear() {
    this.isLoading = true;
    console.info("[BoardListPage] aboutToAppear: waiting for managers init...");
    await this.cookieManager.waitForInit();
    await this.settingsManager.waitForInit();
    this.readAnnouncementIds = this.settingsManager.getReadAnnouncementIds();
    console.info("[BoardListPage] Managers init completed, loading forums...");
    await this.loadForumsAndTimelines();
    console.info("[BoardListPage] Forums loaded, loading board threads...");
    await this.loadBoardThreads(this.currentBoardId);
  }

  async loadForumsAndTimelines() {
    this.boardsLoading = true;
    try {
      const results = await Promise.all([
        this.client.getForumList(),
        this.client.getTimelineList(),
      ]);
      this.communities = results[0];
      this.timelines = results[1];
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error(`加载版块列表失败: ${errorMsg}`);
    } finally {
      this.boardsLoading = false;
    }
  }

  favoriteToBoardThread(favorite: FavoriteThread): BoardThread {
    const raw: BoardThreadRaw = {
      id: String(favorite.id),
      user_id: favorite.userId,
      now: favorite.createdAt,
      title: favorite.title.length > 0 ? favorite.title : undefined,
      content: favorite.content,
      img: favorite.thumbnailUrl
        ? favorite.thumbnailUrl.replace("https://image.nmb.best/thumb/", "").split(".")[0]
        : undefined,
      ext: favorite.thumbnailUrl ? "." + favorite.thumbnailUrl.split(".").pop() : undefined,
      ReplyCount: String(favorite.replyCount),
      fid: favorite.fid !== null ? String(favorite.fid) : undefined,
    };
    return new BoardThread(raw);
  }

  showFavorites() {
    this.currentBoardId = BoardListPage.FAVORITES_BOARD_ID;
    this.currentBoardName = "我的收藏";
    this.isCurrentTimeline = false;
    this.isShowingFavorites = true;
    this.favoriteThreads = this.settingsManager.getFavoriteThreads();
    this.threads = [];
    this.hasMore = false;
    this.errorMessage = this.favoriteThreads.length === 0 ? "暂无收藏的串" : "";
    console.info(`[BoardListPage] Showing favorites: ${this.favoriteThreads.length} threads`);
  }

  async loadBoardThreads(boardId: number, page: number = 1) {
    console.info(`[BoardListPage] loadBoardThreads: boardId=${boardId}, page=${page}`);
    this.isShowingFavorites = false;
    this.errorMessage = "";

    if (page === 1) {
      const cached = await this.client.getBoardCache(boardId, page);
      console.info(`[BoardListPage] getBoardCache result: ${cached !== null ? "found" : "null"}`);

      if (cached !== null && cached.threads && Array.isArray(cached.threads)) {
        console.info(`[BoardListPage] Using cached board threads`);
        this.threads = this.filterReadAnnouncements(cached.threads);
        this.currentPage = 1;
        this.isLoading = false;
        this.hasMore = cached.threads.length > 0;
        this.scroller.scrollToIndex(0, true);
        return;
      }
    }

    await this.fetchBoardThreads(boardId, page);
  }

  async refreshBoardThreads() {
    console.info(`[BoardListPage] refreshBoardThreads: boardId=${this.currentBoardId}`);
    this.readAnnouncementIds = this.settingsManager.getReadAnnouncementIds();
    try {
      const threads = await this.client.getBoardPage(this.currentBoardId, 1);
      this.threads = this.filterReadAnnouncements(threads);
      this.currentPage = 1;
      this.hasMore = threads.length > 0;
      this.errorMessage = "";
      this.scroller.scrollToIndex(0, false);
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要饼干才能访问，请在设置中添加饼干";
      } else {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.errorMessage = `加载失败: ${errorMsg}`;
      }
    } finally {
      this.isRefreshing = false;
    }
  }

  async fetchBoardThreads(boardId: number, page: number) {
    console.info(`[BoardListPage] fetchBoardThreads: boardId=${boardId}, page=${page}`);
    if (page === 1) {
      this.isLoading = true;
    } else {
      this.isLoadingMore = true;
    }

    this.errorMessage = "";
    try {
      const threads = await this.client.getBoardPage(boardId, page);
      console.info(`[BoardListPage] Fetched ${threads.length} threads for page ${page}`);
      if (page === 1) {
        this.threads = this.filterReadAnnouncements(threads);
        this.scroller.scrollToIndex(0, false);
      } else {
        this.threads = [...this.threads, ...this.filterReadAnnouncements(threads)];
      }
      this.currentPage = page;
      this.hasMore = threads.length > 0;
      console.info(
        `[BoardListPage] After fetch: currentPage=${this.currentPage}, hasMore=${this.hasMore}, total threads=${this.threads.length}`,
      );
    } catch (error) {
      console.error(`[BoardListPage] fetchBoardThreads error: ${error}`);
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要饼干才能访问，请在设置中添加饼干";
      } else {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.errorMessage = `加载失败: ${errorMsg}`;
      }
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  filterReadAnnouncements(threads: BoardThread[]): BoardThread[] {
    return threads.filter((thread: BoardThread) => {
      if (thread.id === BoardListPage.ADMIN_ANNOUNCEMENT_THREAD_ID) {
        return this.readAnnouncementIds.indexOf(thread.id) === -1;
      }
      return true;
    });
  }

  async onThreadClick(threadId: number) {
    if (threadId === BoardListPage.ADMIN_ANNOUNCEMENT_THREAD_ID) {
      await this.settingsManager.setAnnouncementRead(threadId);
      this.readAnnouncementIds = this.settingsManager.getReadAnnouncementIds();
      console.info(`[BoardListPage] Marked admin announcement ${threadId} as read`);
    }
    this.getUIContext()
      .getRouter()
      .pushUrl({
        url: "pages/ThreadPage",
        params: { threadId: threadId },
      })
      .catch(() => {
        // TODO: Implement error handling.
      });
  }

  getAllBoards(): BoardInfo[] {
    const result: BoardInfo[] = [];

    for (let i = 0; i < this.timelines.length; i++) {
      const t = this.timelines[i];
      result.push({
        id: -t.id,
        name: t.displayName,
        isTimeline: true,
      });
    }

    for (let i = 0; i < this.communities.length; i++) {
      const community = this.communities[i];
      const forums = community.forums;
      for (let j = 0; j < forums.length; j++) {
        const forum = forums[j];
        if (forum.isValid()) {
          result.push({
            id: forum.id,
            name: forum.displayName,
            isTimeline: false,
          });
        }
      }
    }

    return result;
  }

  getBoardNameMap(): Map<number, string> {
    const map: Map<number, string> = new Map();

    for (let i = 0; i < this.timelines.length; i++) {
      const t = this.timelines[i];
      map.set(-t.id, t.displayName);
    }

    for (let i = 0; i < this.communities.length; i++) {
      const community = this.communities[i];
      const forums = community.forums;
      for (let j = 0; j < forums.length; j++) {
        const forum = forums[j];
        if (forum.isValid()) {
          map.set(forum.id, forum.displayName);
        }
      }
    }

    return map;
  }

  @Builder
  moreMenuBuilder() {
    Menu() {
      MenuItem({
        content: "󰢨 跳转",
      })
        .onClick(() => {
          this.jumpToThreadDialogController = new CustomDialogController({
            builder: JumpToThreadDialog({
              onJump: (threadId: number) => {
                this.jumpToThread(threadId);
              },
            }),
            customStyle: true,
            alignment: DialogAlignment.Center,
          });
          this.jumpToThreadDialogController.open();
        })
      MenuItem({
        content: "󰁳 发串",
      })
        .onClick(() => {
          this.showPostSheet = true;
        })
      MenuItem({
        content: "󰀠 设置",
      })
        .onClick(() => {
          this.getUIContext()
            .getRouter()
            .pushUrl({
              url: "pages/SettingsPage",
            })
            .catch(() => {
              // TODO: Implement error handling.
            });
        })
    };
  }

  jumpToThread(threadId: number): void {
    this.getUIContext()
      .getRouter()
      .pushUrl({
        url: "pages/ThreadPage",
        params: { threadId: threadId },
      })
      .catch(() => {
        // TODO: Implement error handling.
      });
  }

  @Builder
  postSheetBuilder() {
    PostSheet({
      fid: String(this.currentBoardId),
      boardName: this.currentBoardName,
      isShow: $showPostSheet,
      onPostSuccess: async (threadId: string) => {
        console.info(`[BoardListPage] New thread posted: ${threadId}`);
        await this.client.clearBoardCache(this.currentBoardId);
        await this.refreshBoardThreads();
      },
    });
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r("sys.symbol.indentation_left"))
              .fontSize(24)
              .fontColor([$r("app.color.text_primary")])
          }
          .backgroundColor("transparent")
          .width(48)
          .height(48)
          .onClick(() => {
            animateTo(
              {
                duration: 200,
                curve: Curve.EaseOut,
              },
              () => {
                this.showBoardDrawer = !this.showBoardDrawer;
              },
            );
          })
          Text("版块列表")
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r("app.color.text_primary"))
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width("100%")
        .margin({ top: 48, left: 16 })

        if (this.boardsLoading && this.communities.length === 0) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color($r("app.color.primary"))
            Text("加载版块列表...")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
              .margin({ top: 8 })
          }
          .width("100%")
          .height(200)
          .justifyContent(FlexAlign.Center);
        } else {
          List({ scroller: this.boardListScroller }) {
            ListItem() {
              Text("󰃅 收藏夹")
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .padding(8)
                .fontColor($r("app.color.text_secondary"))
                .width("100%")
            }
            ListItem() {
              Row() {
                SymbolGlyph($r("sys.symbol.star"))
                  .fontSize(16)
                  .fontColor([
                    this.currentBoardId === BoardListPage.FAVORITES_BOARD_ID
                      ? $r("app.color.primary")
                      : $r("app.color.text_secondary"),
                  ])
                Text("我的收藏")
                  .fontSize(16)
                  .fontColor(
                    this.currentBoardId === BoardListPage.FAVORITES_BOARD_ID
                      ? $r("app.color.primary")
                      : $r("app.color.text_primary"),
                  )
                  .margin({ left: 8 })
              }
              .padding(16)
              .width("100%")
              .backgroundColor(
                this.currentBoardId === BoardListPage.FAVORITES_BOARD_ID
                  ? $r("app.color.reply_count_bg")
                  : "transparent",
              )
              .borderRadius(16)
              .onClick(() => {
                this.showFavorites();
                this.showBoardDrawer = false;
              })
            }

            if (this.timelines.length > 0) {
              ListItem() {
                Text("󰏕 时间线")
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .padding(8)
                  .fontColor($r("app.color.text_secondary"))
                  .width("100%")
              };
            }
            ForEach(this.timelines, (timeline: Timeline) => {
              ListItem() {
                Text(timeline.displayName)
                  .fontSize(16)
                  .padding(16)
                  .fontColor(
                    this.currentBoardId === -timeline.id
                      ? $r("app.color.primary")
                      : $r("app.color.text_primary"),
                  )
                  .width("100%")
                  .backgroundColor(
                    this.currentBoardId === -timeline.id
                      ? $r("app.color.reply_count_bg")
                      : "transparent",
                  )
                  .borderRadius(16)
                  .onClick(() => {
                    this.currentBoardId = -timeline.id;
                    this.currentBoardName = timeline.displayName;
                    this.isCurrentTimeline = true;
                    this.loadBoardThreads(-timeline.id, 1);
                    this.showBoardDrawer = false;
                  })
              };
            })
            ForEach(this.communities, (community: Community) => {
              ListItem() {
                Text("󰝴 " + community.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r("app.color.text_secondary"))
                  .width("100%")
                  .padding(8)
              };
              ForEach(community.forums, (forum: Forum) => {
                ListItem() {
                  Text(forum.displayName)
                    .fontSize(16)
                    .fontColor(
                      this.currentBoardId === forum.id
                        ? $r("app.color.primary")
                        : $r("app.color.text_primary"),
                    )
                    .width("100%")
                    .padding(16)
                    .backgroundColor(
                      this.currentBoardId === forum.id
                        ? $r("app.color.reply_count_bg")
                        : "transparent",
                    )
                    .borderRadius(16)
                    .onClick(() => {
                      this.currentBoardId = forum.id;
                      this.currentBoardName = forum.displayName;
                      this.isCurrentTimeline = false;
                      this.loadBoardThreads(forum.id, 1);
                      this.showBoardDrawer = false;
                    })
                };
              });
            })
          }
          .padding(16)
          .height("100%")
          .width("100%")
          .layoutWeight(1)
          .chainAnimation(true)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .divider({ strokeWidth: 1, color: $r("app.color.divider") });
        }
      }
      .width("100%")
      .height("100%")
      .hitTestBehavior(this.showBoardDrawer ? HitTestMode.Transparent : HitTestMode.Block)
      .backgroundColor($r("app.color.card_background"))
      Column() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r("sys.symbol.indent_right"))
              .fontSize(24)
              .fontColor([$r("app.color.text_primary")])
          }
          .backgroundColor("transparent")
          .width(48)
          .height(48)
          .onClick(() => {
            animateTo(
              {
                duration: 300,
                curve: Curve.EaseOut,
              },
              () => {
                this.showBoardDrawer = !this.showBoardDrawer;
              },
            );
          })
          Text(this.currentBoardName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r("app.color.text_primary"))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .margin({ left: 8 })
          Row() {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r("sys.symbol.dot_grid_2x2"))
                .fontSize(24)
                .fontColor([$r("app.color.text_primary")])
            }
            .width(48)
            .height(48)
            .backgroundColor("transparent")
            .bindMenu(this.moreMenuBuilder)
          }
        }
        .width("100%")
        .padding({ left: 8, right: 8, top: 44, bottom: 8 })

        if (this.errorMessage) {
          Column() {
            SymbolGlyph($r("sys.symbol.exclamationmark_circle"))
              .fontSize(48)
              .fontColor([$r("app.color.error")])
              .margin({ bottom: 16 })
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r("app.color.error"))
              .textAlign(TextAlign.Center)
              .width("100%")
              .borderRadius(16)
          }
          .width("100%")
          .padding(16)
          .margin(8);
        }

        if (this.isLoading && this.threads.length === 0) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r("app.color.primary"))
            Text("加载中...")
              .fontSize(14)
              .fontColor($r("app.color.text_secondary"))
              .margin({ top: 16 })
          }
          .width("100%")
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center);
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            Row() {
              List({ scroller: this.scroller }) {
                if (this.isShowingFavorites) {
                  ForEach(this.favoriteThreads, (favorite: FavoriteThread) => {
                    ListItem() {
                      ThreadListItem({
                        thread: this.favoriteToBoardThread(favorite),
                        boardNameMap: new Map(),
                        isTimeline: false,
                        onItemClick: (threadId: number) => {
                          this.onThreadClick(threadId);
                        },
                      })
                    }
                    .width("100%")
                    .margin({ bottom: 8 });
                  });
                } else {
                  ForEach(this.threads, (thread: BoardThread) => {
                    ListItem() {
                      ThreadListItem({
                        thread: thread,
                        boardNameMap: this.getBoardNameMap(),
                        isTimeline: this.isCurrentTimeline,
                        onItemClick: (threadId: number) => {
                          this.onThreadClick(threadId);
                        },
                      })
                    }
                    .width("100%")
                    .margin({ bottom: 8 });
                  });
                }

                if (this.isLoadingMore && !this.isShowingFavorites) {
                  ListItem() {
                    Row() {
                      LoadingProgress()
                        .width(24)
                        .height(24)
                        .color($r("app.color.primary"))
                      Text("加载中...")
                        .fontSize(14)
                        .fontColor($r("app.color.text_secondary"))
                        .margin({ left: 8 })
                    }
                    .width("100%")
                    .height(60)
                    .justifyContent(FlexAlign.Center)
                  };
                }
              }
              .width("100%")
              .height("100%")
              .layoutWeight(1)
              .borderRadius(16)
              .backgroundColor($r("app.color.background"))
              .chainAnimation(true)
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .scrollBar(BarState.Off)
              .clip(true)
              .margin({ left: 12, right: 4, top: 16, bottom: 16 })
              .onScrollIndex((start: number, end: number) => {
                console.info(
                  `[BoardListPage] onScrollIndex: start=${start}, end=${end}, threads.length=${this.threads.length}, hasMore=${this.hasMore}, isLoadingMore=${this.isLoadingMore}, isLoading=${this.isLoading}, isRefreshing=${this.isRefreshing}, currentPage=${this.currentPage}`,
                );
                if (
                  this.hasMore &&
                  !this.isLoadingMore &&
                  !this.isLoading &&
                  !this.isRefreshing &&
                  end >= this.threads.length - 3
                ) {
                  console.info(
                    `[BoardListPage] Triggering load more: page=${this.currentPage + 1}`,
                  );
                  this.loadBoardThreads(this.currentBoardId, this.currentPage + 1);
                }
              })
              ScrollBar({
                scroller: this.scroller,
                direction: ScrollBarDirection.Vertical,
                state: BarState.Auto,
              }) {
                Text("  ")
                  .backgroundColor($r("app.color.primary"))
                  .borderRadius(2)
              }
              .width(4)
              .height("100%")
              .margin({ right: 4 })
              .backgroundColor(Color.Transparent)
            }
            .width("100%")
            .height("100%")
            .layoutWeight(1)
          }
          .refreshOffset(64)
          .onRefreshing(() => {
            this.refreshBoardThreads();
          })
          .width("100%")
          .layoutWeight(1);
        }
      }
      .width("100%")
      .height("100%")
      .backgroundColor($r("app.color.background"))
    }
    .sideBarWidth(280)
    .minSideBarWidth(280)
    .maxSideBarWidth(280)
    .showSideBar(this.showBoardDrawer)
    .showControlButton(false)
    .sideBarPosition(SideBarPosition.Start)
    .onChange((value: boolean) => {
      this.showBoardDrawer = value;
    })
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet($$this.showPostSheet, this.postSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: Color.Transparent,
      onDisappear: () => {
        this.showPostSheet = false;
      },
    });
  }
}
