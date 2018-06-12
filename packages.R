library(rvest)
info = read_html("http://bit.ly/2sUdD9h") %>%
  html_nodes(xpath = '/html/body/table') %>%
  html_table()
info = info[[1]]
info = info[order(info$Tinstall, decreasing = TRUE), c(1, 4, 2, 3, 5, 6)]
info = info[info$Tinstall > 30, ]
