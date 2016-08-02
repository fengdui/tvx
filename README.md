# tvx

TVX Is a simple HTTP/HTTPS proxy server which was written by Erlang.

1. Default port is 10086


User guide:

1.  starting it with the following command:
$>  erl -detached -sname tvx -pa ebin -s tvx start



2. Setting the proxy address in your web browser, specs is below:
   <server_IP>:10086


3. Refresh your web page and all in works.

==========================================================
    中文文档如下
TVX是一个简单的HTTP/HTTPS代理服务器，采用Erlang语言编写
它的默认端口是10086 (如果需要改变请pull回去自行修改代码)

运行前提:
1. 当前机器必须安装Erlang Runtimes环境，如果没有安装请在此下载：
   http://www.erlang.org

2. 当前主机的10086端口未被占用


运行说明：
1、SHELL/Command中输入命令： 
   erl -detached -sname tvx -pa ebin -s tvx start

 在windows下 -detached可能无效而导致进程无法启动，请输入： 
   erl -noshell -sname tvx -pa ebin -s tvx start 

2、在浏览器中设置网络代理，指向： <服务器IP>:10086

3、刷新浏览器或者重新打开浏览器，此时该浏览器即采用TVX实现代理上网
