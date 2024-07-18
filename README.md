# shadowsocks_cj

#### 介绍
shadowsocks的仓颉实现

#### 软件架构
软件架构说明

#### 安装教程

1.  xxxx
2.  xxxx
3.  xxxx

#### 使用说明

1.  xxxx
2.  xxxx
3.  xxxx

#### Todo list

- [_] 性能优化
- [_] 完备加密算法

#### Benchmark

使用ab-proxy进行测试，结果如下

未使用代理时
```shell
# round 1
sirnple@sirnple:~/repos/shadowsocks_cj$ ab-proxy -c 10 -n 1000 https://www.baidu.com
Benchmarking 'https://www.baidu.com' with a total of 1000 GET requests:

Number of bursts:             1                                  
Number of request per burst   1000
Concurrency level:            10
Time taken for tests:         1.547418107s

Total initiated requests:     1000
   Completed requests:        1000
      HTTP-200 completed:     1000
   Failed requests:           0

Total transferred:            227000 bytes
Requests per second:          646.238
Time per request:             1.547418ms
# round 2
sirnple@sirnple:~/repos/shadowsocks_cj$ ab-proxy -c 10 -n 1000 https://www.baidu.com
Benchmarking 'https://www.baidu.com' with a total of 1000 GET requests:

Number of bursts:             1                                  
Number of request per burst   1000
Concurrency level:            10
Time taken for tests:         1.552358112s

Total initiated requests:     1000
   Completed requests:        1000
      HTTP-200 completed:     1000
   Failed requests:           0

Total transferred:            227000 bytes
Requests per second:          644.181
Time per request:             1.552358ms
# round 3
sirnple@sirnple:~/repos/shadowsocks_cj$ ab-proxy -c 10 -n 1000 https://www.baidu.com
Benchmarking 'https://www.baidu.com' with a total of 1000 GET requests:

Number of bursts:             1                                   
Number of request per burst   1000
Concurrency level:            10
Time taken for tests:         1.792528084s

Total initiated requests:     1000
   Completed requests:        1000
      HTTP-200 completed:     1000
   Failed requests:           0

Total transferred:            227000 bytes
Requests per second:          557.871
Time per request:             1.792528ms
```

使用代理时
```shell
# round 1
sirnple@sirnple:~/repos/shadowsocks_cj$ ab-proxy -c 10 -n 1000 --proxy socks5://localhost:1081 https://www.baidu.com
Benchmarking 'https://www.baidu.com' using proxy 'socks5://localhost:1081' with a total of 1000 GET requests:

Number of bursts:             1                                   
Number of request per burst   1000
Concurrency level:            10
Time taken for tests:         1.69933647s

Total initiated requests:     1000
   Completed requests:        1000
      HTTP-200 completed:     1000
   Failed requests:           0

Total transferred:            227000 bytes
Requests per second:          588.465
Time per request:             1.699336ms
# round 2
sirnple@sirnple:~/repos/shadowsocks_cj$ ab-proxy -c 10 -n 1000 --proxy socks5://localhost:1081 https://www.baidu.com
Benchmarking 'https://www.baidu.com' using proxy 'socks5://localhost:1081' with a total of 1000 GET requests:

Number of bursts:             1                                   
Number of request per burst   1000
Concurrency level:            10
Time taken for tests:         1.734960491s

Total initiated requests:     1000
   Completed requests:        1000
      HTTP-200 completed:     1000
   Failed requests:           0

Total transferred:            227000 bytes
Requests per second:          576.382
Time per request:             1.73496ms
# round 3
sirnple@sirnple:~/repos/shadowsocks_cj$ ab-proxy -c 10 -n 1000 --proxy socks5://localhost:1081 https://www.baidu.com
Benchmarking 'https://www.baidu.com' using proxy 'socks5://localhost:1081' with a total of 1000 GET requests:

Number of bursts:             1                                   
Number of request per burst   1000
Concurrency level:            10
Time taken for tests:         2.207380256s

Total initiated requests:     1000
   Completed requests:        1000
      HTTP-200 completed:     1000
   Failed requests:           0

Total transferred:            227000 bytes
Requests per second:          453.026
Time per request:             2.20738ms
```

未使用代理时，平均的Requests per second为`(646.238 + 644.181 + 557.871)/3 = 616.0966666667`，使用代理时，平均的Requests per second为`(576.382 + 576.382 + 453.026)/3 = 535.2633333333`，降低了14%的Requests per second。

#### 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request


#### 特技

1.  使用 Readme\_XXX.md 来支持不同的语言，例如 Readme\_en.md, Readme\_zh.md
2.  Gitee 官方博客 [blog.gitee.com](https://blog.gitee.com)
3.  你可以 [https://gitee.com/explore](https://gitee.com/explore) 这个地址来了解 Gitee 上的优秀开源项目
4.  [GVP](https://gitee.com/gvp) 全称是 Gitee 最有价值开源项目，是综合评定出的优秀开源项目
5.  Gitee 官方提供的使用手册 [https://gitee.com/help](https://gitee.com/help)
6.  Gitee 封面人物是一档用来展示 Gitee 会员风采的栏目 [https://gitee.com/gitee-stars/](https://gitee.com/gitee-stars/)
