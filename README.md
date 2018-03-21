# ipynb-codeblock-parser

Simple utility to parse the code blocks in an ipynb file and ensure the reported output matches
the actual output. Usage:

``` shell
perl parser.pl /path/to/notebook.ipynb
```

This opens an iPython shell and ensures the reported output matches actual output. For example,

``` python
>>> a = 7
>>> a
7
```

will correctly pass, while

``` python
>>> a = 7
>>> a
2
```

will rightly fail with the error message

```
Error!

    '7'
    
does not match

    '2'
    
in

    >>> a
```
