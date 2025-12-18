# WebDAV-aria2-sender
将WebDAV中的文件批量发送到aria2

本项目是为了便于WebDAV下整个目录文件进行下载而诞生的

使用条件：本项目为bash脚本+Java处理器，编译时使用的Java版本为17，Windows需要使用`git bash`

**已知问题：** 如果服务端返回的xml存在文件递归列出情况（即当前目录下子目录、子目录的子目录中的文件全部被列出），将会导致目录结构被破坏（所有文件被下载到同级目录）

**已知会发生问题的服务器：** Cloudreve

用法（主程序WebDAV-aria2-sender.sh）：
```bash
-w <WebDav地址> \
-u <WebDAV用户名> \
-p <WebDAV密码> \
-r <RPC地址，使用http而不是ws，本地时需要使用`127.0.0.1`不应使用localhost> \
-t <aria2的token> \
-d <下载路径，Windows使用时需将反斜杠'\'替换为斜杠'/'> 
```

示例：将pikpak上存储的`/Pack From Shared/aaa`文件夹中的文件通过有鉴权要求的aria2下载到`E:\Downloads`
```bash
-w https://dav.mypikpak.com/Pack%20From%20Shared/aaa/ \
-u user \
-p passwd \
-r http://127.0.0.1:16800/jsonrpc \
-t token \
-d "E:/Downloads"
```

示例：将pikpak上存储的`/Pack From Shared/aaa`文件夹中的文件下载到aria2默认下载目录
```bash
-w https://dav.mypikpak.com/Pack%20From%20Shared/aaa/ \
-u user \
-p passwd \
-r http://127.0.0.1:6800/jsonrpc \
```

用法（WebDAV的xml解析器WebDAVParser.jar）：

此程序用来将WebDAV列出文件的xml解析为文件列表，每行一个，格式为`url<tab>文件名`

可以用下面的命令获取xml

```bash
curl -X PROPFIND -o webdav_urls.xml -u username:passwd https://webdav.example.com/parentdir/subdir/
```
然后传入到程序中，基础url就是`https://webdav.example.com/` ，不过写成`https://webdav.example.com/parentdir/subdir/` 也能用
```java
java WebDAVParser <xml文件路径> <输出文件路径> <基础URL>
```


用法（aria2发送程序aria2-add-from-list.sh）：
```bash
-u <WebDAV用户名> \
-p <WebDAV密码> \
-r <RPC地址，使用http而不是ws，本地时需要使用`127.0.0.1`不应使用localhost> \
-t <aria2的token> \
-d <下载路径，Windows使用时需将反斜杠'\'替换为斜杠'/'> \
-l <指定文件列表>
```

示例：下载列表`webdav_urls.txt`中的文件到`E:\Downloads`
```bash
-u user \
-p passwd \
-r http://127.0.0.1:6880/jsonrpc \
-t token \
-d "E:/Downloads" \
-l webdav_urls.txt
```