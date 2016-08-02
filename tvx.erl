%
% TVX 高匿HTTP/HTTPS代理服务器
%

-module(tvx).
-author("liuhao0927@163.com").

-export([start/0]).

%
% 启动入口
%
start() -> spawn(fun() -> 
  process_flag(trap_exit,true),
  {ok,Listen} = gen_tcp:listen(10086,[binary,{packet,0},{active,true}]),
  spawn(fun() -> start_supervisor(self()) end),
  main_loop(Listen)
end).

%
% 启动监督者,以便在服务器进程崩溃时动态恢复
%
start_supervisor(Tvx) ->
   process_flag(trap_exit,true),
   link(Tvx),
   receive
      {'EXIT',What,Why} ->
                io:format("TVX server [~p] has been crash, caused by ~p~n",[What,Why]),
                start() 	   
   end.

main_loop(Listen) ->
   {ok,Sock} = gen_tcp:accept(Listen),
    Pid = spawn(fun() -> session(Sock,#{}) end),
    gen_tcp:controlling_process(Sock, Pid),
    main_loop(Listen).


session(Sock,Context) ->
  receive
  	  {tcp,Sock,Bin} ->
  	         case maps:size(Context) of
  	         	0 -> 
    	         	    %
    	         	    % 解析请求头
    	         	    %
                    [Command | NormalHeader] = case string:tokens(binary_to_list(Bin),"\r\n") of
                        [C] ->
                             [C | []];
                        Any -> Any
                    end,
    	         	    [Method,Url,Protocol] = string:tokens(Command," "),
    	         	    io:format("=============================\n"),
    	         	    io:format("\tMethod:\t~p\n",[Method]),
           			    io:format("\tURL:\t~p\n",[Url]),
           			    io:format("\tProtocol:\t~p\n",[Protocol]),

           			    Headers = resovle_http_headers(NormalHeader,#{}),


                    Addr = case Method of
                    	"CONNECT" ->
                    	    %
                    	    % 解析HTTPS请求地址
                    	    %
                    	   Url;
                    	_ ->
                    	   maps:get("Host",Headers)
                    end,
                    %
                    % 分析出远程目标服务器的主机名和端口
                    %
         			      [RemoteHost,RemotePort] = case string:tokens(Addr,":") of
			                [A] -> [A,80]; % 默认80端口
			                [A,B] -> case is_integer(B) of
			             	           true -> [A,B];
			             	           false -> [A,list_to_integer(B)]
			             	      end
			              end,

                    %
                    % 建立到目标服务器的连接
                    %
                    %io:format("Remote host is ~p, Remote port is ~p~n",[RemoteHost,RemotePort]),

                    case gen_tcp:connect(RemoteHost,RemotePort,[binary,{packet,0}]) of
                    	{ok,Remote} ->
                    	        case Method of
			         				%
			         				% HTTPS CHANNEL
			         				%
			         				"CONNECT" ->
			         				     io:format("Active HTTPS CHANNEL\n"),
			         				     PidRemote = spawn(fun() -> 
			         				     	 receive_remote_data(Sock,Remote)
			         				     end),

			         				     gen_tcp:controlling_process(Remote, PidRemote),
			         				     
			         				     gen_tcp:send(Sock,<<"HTTP/1.1 200 Connection established\r\n\r\n">>),

			         				     session(Sock,#{remoteSock => Remote});

                      %
                      % HTTP CHANNEL
                      %
			         				_ ->
			         				     io:format("ACTIVE HTTP CHANNEL::~p\n",[Remote]),
			         				     %
			         				     % 原封不动发送客户端的请求头到远程服务器
			         				     %
			         				     PidRemote = spawn(fun() -> 
			         				     	 receive_remote_data(Sock,Remote)
			         				     end),

			         				     gen_tcp:controlling_process(Remote, PidRemote),
			         				     gen_tcp:send(Remote,Bin),
			         				     session(Sock,#{remoteSock => Remote})

			         			end;
                    	_ ->
                    	        %
                    	        % 无法向远程服务器建立连接直接返回500
                    	        %
                    	        gen_tcp:send(Sock,<<"HTTP/1.1 500 Connection FAILED\r\n\r\n">>)
                    end;
  	         	_ ->
  	         	    %
  	         	    % 继续转发数据
  	         	    %
  	         	    {ok,Remote} = maps:find(remoteSock,Context),
  	         	    gen_tcp:send(Remote,Bin),
  	         	    session(Sock,#{remoteSock => Remote})
  	         end;
  	   {tcp_closed,Sock} ->
  	          io:format("client closed\n")
  end.


receive_remote_data(Source,Remote) ->
    receive
	    {tcp,Remote,Bin} ->
	        gen_tcp:send(Source,Bin),
	        %io:format("Receive remote data ~p~n",[Bin]),
	        receive_remote_data(Source,Remote);
	    {tcp_closed,_} ->
	        io:format("=========server closed ==========\n"),
	        gen_tcp:close(Source)
	end.

%
% 解析HTTP请求头
%
resovle_http_headers([],M) -> M;
resovle_http_headers([H|T],M) ->
     [F|O] = string:tokens(H,":"),
     resovle_http_headers(T,maps:put(F,concat_list(O,""),M)).

concat_list([],R) -> R;
concat_list([H],R) -> 
  concat_list([],R ++ string:strip(H));
concat_list([H|T],R) ->
  concat_list(T,R ++ string:strip(H) ++ ":").