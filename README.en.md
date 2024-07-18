# shadowsocks_cj

#### Description
shadowsocks的仓颉实现

#### Software Architecture
Software architecture description

#### Installation

1.  xxxx
2.  xxxx
3.  xxxx

#### Instructions

1.  xxxx
2.  xxxx
3.  xxxx

#### Todo list

- [ ] Optimize performance
- [ ] Add support for more encryption algorithms

#### Benchmark

Testing was done using ab-proxy, the result is as follows

No proxy
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

Using proxy
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

When no proxy is used, the average Requests per second is `(646.238 + 644.181 + 557.871)/3 = 616.0966666667`, and when a proxy is used, the average Requests per second is `(576.382 + 576.382 + 453.026)/3 = 535.2633333333`, which reduces 14% of Requests per second.

#### Contribution

1.  Fork the repository
2.  Create Feat_xxx branch
3.  Commit your code
4.  Create Pull Request


#### Gitee Feature

1.  You can use Readme\_XXX.md to support different languages, such as Readme\_en.md, Readme\_zh.md
2.  Gitee blog [blog.gitee.com](https://blog.gitee.com)
3.  Explore open source project [https://gitee.com/explore](https://gitee.com/explore)
4.  The most valuable open source project [GVP](https://gitee.com/gvp)
5.  The manual of Gitee [https://gitee.com/help](https://gitee.com/help)
6.  The most popular members  [https://gitee.com/gitee-stars/](https://gitee.com/gitee-stars/)
