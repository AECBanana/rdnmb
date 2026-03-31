import router from "@ohos.router";
import { AnoBBSClient } from "../api/Client";
import { BoardThread } from "../models/Post";
import { Community, Timeline, Forum } from "../models/Forum";
import { ThreadListItem } from "../components/ThreadListItem";
import { RequiresLoginException } from "../models/Errors";
import { CookieManager } from "../utils/CookieManager";

interface BoardInfo {
  id: number;
  name: string;
  isTimeline: boolean;
}

@Entry
@Component
struct BoardListPage {
  @State threads: BoardThread[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = "";
  @State currentPage: number = 1;
  @State currentBoardId: number = -1;
  @State currentBoardName: string = "时间线";
  @State showBoardDrawer: boolean = false;
  @State showMoreMenu: boolean = false;
  @State communities: Community[] = [];
  @State timelines: Timeline[] = [];
  @State boardsLoading: boolean = true;

  private client: AnoBBSClient = new AnoBBSClient();
  private scroller: Scroller = new Scroller();
  private cookieManager: CookieManager = CookieManager.getInstance();

  async aboutToAppear() {
    console.info("[BoardListPage] aboutToAppear: waiting for CookieManager init...");
    await this.cookieManager.waitForInit();
    console.info("[BoardListPage] CookieManager init completed, loading forums...");
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

  async loadBoardThreads(boardId: number, page: number = 1) {
    console.info(`[BoardListPage] loadBoardThreads: boardId=${boardId}, page=${page}`);
    const cached = await this.client.getBoardCache(boardId, page);
    console.info(`[BoardListPage] getBoardCache result: ${cached !== null ? "found" : "null"}`);
    
    if (cached !== null && cached.threads && Array.isArray(cached.threads)) {
      console.info(`[BoardListPage] Using cached board threads`);
      this.threads = cached.threads;
      this.isLoading = false;
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = "";
    try {
      const threads = await this.client.getBoardPage(boardId, page);
      if (page === 1) {
        this.threads = threads;
      } else {
        const newThreads: BoardThread[] = [];
        for (let i = 0; i < this.threads.length; i++) {
          newThreads.push(this.threads[i]);
        }
        for (let i = 0; i < threads.length; i++) {
          newThreads.push(threads[i]);
        }
        this.threads = newThreads;
      }
      this.currentPage = page;
    } catch (error) {
      if (error instanceof RequiresLoginException) {
        this.errorMessage = "需要饼干才能访问，请在设置中添加饼干";
      } else {
        const errorMsg = error instanceof Error ? error.message : String(error);
        this.errorMessage = `加载失败: ${errorMsg}`;
      }
    } finally {
      this.isLoading = false;
    }
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

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r("sys.symbol.more")).fontSize(24)
          }
          .backgroundColor("transparent")
          .width(48)
          .height(48)
          .onClick(() => {
            this.showBoardDrawer = true;
          })
          Text(this.currentBoardName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r("app.color.text_primary"))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          Row() {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r("sys.symbol.ellipsis_circle")).fontSize(24)
            }
            .width(48)
            .height(48)
            .backgroundColor("transparent")
            .onClick(() => {
              this.showMoreMenu = !this.showMoreMenu;
            })
          }
        }
        .width("100%")
        .padding({ left: 8, right: 8, top: 44, bottom: 8 })

        if (this.errorMessage) {
          Row() {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r("app.color.error"))
              .textAlign(TextAlign.Center)
              .width("100%")
          }
          .width("100%")
          .padding(16)
          .backgroundColor($r("app.color.card_background"))
          .margin({ top: 8 });
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
          List({ scroller: this.scroller }) {
            ForEach(this.threads, (thread: BoardThread) => {
              ListItem() {
                ThreadListItem({
                  thread: thread,
                  onItemClick: (threadId: number) => {
                    router.pushUrl({
                      url: "pages/ThreadPage",
                      params: { threadId: threadId },
                    });
                  },
                })
              }
              .margin({ top: 8, left: 12, right: 12 });
            })

            if (this.threads.length > 0) {
              ListItem() {
                Row() {
                  if (this.isLoading) {
                    LoadingProgress().width(24).height(24).color($r("app.color.primary"));
                  } else {
                    Button("加载更多")
                      .fontSize(14)
                      .fontColor($r("app.color.primary"))
                      .backgroundColor("transparent")
                      .onClick(() => {
                        this.loadBoardThreads(this.currentBoardId, this.currentPage + 1);
                      });
                  }
                }
                .width("100%")
                .height(60)
                .justifyContent(FlexAlign.Center)
              };
            }
          }
          .width("100%")
          .layoutWeight(1)
          .backgroundColor($r("app.color.background"))
          .padding({ top: 8, bottom: 8 });
        }
      }
      .width("100%")
      .height("100%")
      .backgroundColor($r("app.color.background"))

      if (this.showMoreMenu) {
        Column() {
          Column() {
            Row() {
              SymbolGlyph($r("sys.symbol.plus"))
                .fontSize(20)
                .fontColor([Color.Black])
              Text("发串")
                .fontSize(16)
                .fontColor(Color.Black)
                .margin({ left: 12 })
            }
            .width("100%")
            .padding(16)
            .onClick(() => {
              this.showMoreMenu = false;
              router.pushUrl({
                url: "pages/PostPage",
              });
            })
            Row() {
              SymbolGlyph($r("sys.symbol.gearshape"))
                .fontSize(20)
                .fontColor([Color.Black])
              Text("设置")
                .fontSize(16)
                .fontColor(Color.Black)
                .margin({ left: 12 })
            }
            .width("100%")
            .padding(16)
            .onClick(() => {
              this.showMoreMenu = false;
              router.pushUrl({
                url: "pages/SettingsPage",
              });
            })
          }
          .width(150)
          .backgroundColor($r("app.color.card_background"))
          .borderRadius(8)
          .shadow({ radius: 8, color: "#20000000" })
        }
        .margin({ top: 56, right: 16 })
        .onClick(() => {
          this.showMoreMenu = false;
        });
      }

      if (this.showBoardDrawer) {
        Column() {
          Row() {
            Column() {
              Row() {
                Text("版块列表")
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r("app.color.text_primary"))
                  .layoutWeight(1)

                if (this.boardsLoading) {
                  LoadingProgress().width(20).height(20).color($r("app.color.primary"));
                }
              }
              .width("100%")
              .padding(16)

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
                List() {
                  if (this.timelines.length > 0) {
                    ListItem() {
                      Text("时间线")
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r("app.color.text_secondary"))
                        .width("100%")
                        .padding({ left: 16, top: 8, bottom: 8 })
                        .backgroundColor($r("app.color.background"))
                    };
                  }
                  ForEach(this.timelines, (timeline: Timeline) => {
                    ListItem() {
                      Text(timeline.displayName)
                        .fontSize(16)
                        .fontColor(
                          this.currentBoardId === -timeline.id
                            ? $r("app.color.primary")
                            : $r("app.color.text_primary"),
                        )
                        .width("100%")
                        .padding(16)
                        .backgroundColor(
                          this.currentBoardId === -timeline.id
                            ? $r("app.color.reply_count_bg")
                            : "transparent",
                        )
                        .borderRadius(8)
                        .onClick(() => {
                          this.currentBoardId = -timeline.id;
                          this.currentBoardName = timeline.displayName;
                          this.showBoardDrawer = false;
                          this.loadBoardThreads(-timeline.id, 1);
                        })
                    };
                  })
                  ForEach(this.communities, (community: Community) => {
                    ListItem() {
                      Column() {
                        Text(community.name)
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor($r("app.color.text_secondary"))
                          .width("100%")
                          .padding({ left: 16, top: 8, bottom: 8 })
                          .backgroundColor($r("app.color.background"))
                        ForEach(community.forums, (forum: Forum) => {
                          if (forum.isValid()) {
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
                              .borderRadius(8)
                              .onClick(() => {
                                this.currentBoardId = forum.id;
                                this.currentBoardName = forum.displayName;
                                this.showBoardDrawer = false;
                                this.loadBoardThreads(forum.id, 1);
                              });
                          }
                        })
                      }.width("100%")
                    };
                  })
                }
                .width("100%")
                .layoutWeight(1)
                .divider({ strokeWidth: 1, color: $r("app.color.divider") });
              }
            }
            .width(280)
            .height("100%")
            .backgroundColor($r("app.color.card_background"))
            Column()
              .layoutWeight(1)
              .height("100%")
              .backgroundColor("#80000000")
              .onClick(() => {
                this.showBoardDrawer = false;
              })
          }
          .width("100%")
          .height("100%")
        }
        .width("100%")
        .height("100%");
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
