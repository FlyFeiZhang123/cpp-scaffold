# third_party/ — vendored 依赖

这里放 **CPM 拉不了、conan 也装不了** 的库：

| 场景 | 做法 |
|---|---|
| 整个库 fork、改动很多 | 把改好的源码整个拷进这里，接法见下 |
| 私有 / 公司库，不能放公网 | 放这里，`add_subdirectory` 或 `SOURCE_DIR` |
| 只改官方库几个文件 | 不用 vendored —— 用 CPM 的 `PATCHES`（cmake/Dependencies.cmake 写法⑥） |

## 怎么接进构建

### 方式 A：add_subdirectory（最直接）

根 CMakeLists.txt 的 "3.5 第三方库统一链接" 处加：

```cmake
add_subdirectory(third_party/foo)
target_link_libraries(${LIB_NAME} PRIVATE foo::foo)
```

> 注意：`foo::foo` 这个名字要和放进来的库真正产出的 target 一致，否则链接报找不到。

### 方式 B：CPMAddPackage + SOURCE_DIR（推荐，走 CPM 流程）

在 cmake/Dependencies.cmake 里声明一行：

```cmake
CPMAddPackage(NAME foo SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/foo)
```

`foo_SOURCE_DIR` 等变量照常导出，后续用法和 CPM 拉远程版一致。

## 和 CPM 覆盖机制的关系

如果本地 fork 只是**临时调试用、不打算常驻项目**，别 vendored 进这里 —— 在
cmake/Dependencies.cmake 顶部 set 一行即可，注释/取消注释切换官方版和本地版：

```cmake
set(CPM_foo_SOURCE "/home/me/forks/foo")   # 注释掉这行 = 恢复官方
```

三种本地机制的完整写法和示例见 cmake/Dependencies.cmake 注释里的"写法④⑤⑥"。

## 小技巧：fork 尽量保留 .git

如果本地版本只是官方版的小改动，clone 进 third_party/ 时保留 `.git`，方便日后合并上游：

```bash
git clone --branch v1.0 https://github.com/foo/foo.git third_party/foo
cd third_party/foo
# 改代码，提交到自己仓库
```

之后随时 `git fetch` + `git merge` 拉官方更新，不用手动对比差异。
对比：CPM 的 `PATCHES`（写法⑥）适合**只改几个文件、不想维护整个 fork** 的情况。
