#' draw_tree
#'
#' @export
#'

draw_tree <- function(
  tree = NULL,
  pp = NULL,
  tree_title = NULL,
  only.get.stats = FALSE,
  trim_tree_pp = NULL
) {

  require("Rgraphviz")
  require("plotly")
  require("magrittr")

  if( ! is.null(trim_tree_pp) ) {
    tmp <- trim_tree(tree=tree,pp=pp,pp.thr=trim_tree_pp)
    tree <- tmp$tree
    pp <- tmp$pp

  }

  if(is.null(tree_title)) tree_title <- "Tree"

  matrix <- matrix(0, ncol = nrow(tree), nrow = nrow(tree))

  for( i in 1:(nrow(tree)-1) ) {
    p <- tree[i,"Par"]
    c <- tree[i,"ID"]
    matrix[p,c] <- 1
  }

  rownames(matrix) <- tree$ID
  colnames(matrix) <- tree$ID
  labels = tree$ID

  graph <- new("graphAM", adjMat = matrix, edgemode = 'directed')

  lGraph <- layoutGraph(graph)
  ninfo <- nodeRenderInfo(lGraph)

  node_state <- apply(pp,1,function(x) return( which.max(x) )) - 2

  node_labels <- paste(
    tree$meaning,
    "<br>",
    "State: ",node_state,
    "<br>",
    "PP_active = ",round(1-pp[,2],2),
    sep = ""
  )

  nodeRI = data.frame(
    NODE    = names(ninfo$nodeX),
    PP1     = pp[,1],
    PP2     = pp[,2],
    PP3     = pp[,3],
    NODEX   = ninfo$nodeX,
    NODEY   = ninfo$nodeY,
    MEANING = tree$meaning,
    LABEL   = node_labels
  )

  col_pal_risk <- colorRampPalette( c( "white", rgb(112, 28, 28, max=255) ) )( 100 )
  col_pal_prot <- colorRampPalette( c( "white", rgb(8, 37, 103, max=255) ) )(100)

  cols1 <- map2color(pp[,3], col_pal_risk, limits = c(0,1))
  cols2 <- map2color(pp[,1], col_pal_prot, limits = c(0,1))

  bar.cols <- rep("white",nrow(tree))
  state.col <- apply(pp[,c(1,3)],1,which.max)
  bar.cols[state.col == 1] <- cols2[state.col == 1]
  bar.cols[state.col == 2] <- cols1[state.col == 2]

  cols <- rep("white",nrow(tree))
  idx <- which(node_state == 1)
  cols[idx] <- cols1[idx]
  idx <- which(node_state == -1)
  cols[idx] <- cols2[idx]

  nodeRI$COL <- bar.cols

  attrs <- list(node = list(fillcolor = 'white'), edge = list(arrowsize=0.5))

  names(cols) <- labels

  nattrs <- list(fillcolor=cols)

  nodes <- buildNodeList(graph, nodeAttrs=nattrs, defAttrs=attrs$node)
  edges <- buildEdgeList(graph)
  vv <- agopen(name="foo", nodes=nodes, edges=edges, attrs=attrs,
    edgeMode="directed")

  x <- vv
  y <- x@layoutType
  x <- graphLayout(x, y)
  ur <- upRight(boundBox(x))
  bl <- botLeft(boundBox(x))

  out <- list()
  out$nodeRI <- nodeRI

  ##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  ## Initalize plotly
  ##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  p <- plotly::plot_ly()

  xlim1 <- getX(ur)*1.02
  xlim0 <- -xlim1*0.02
  xlim <- c(xlim0, xlim1)

  ## Add an axis.
  p %<>% plotly::layout(
    p,
    title      = tree_title,
    xaxis      = list(
      title          = "",
      showgrid       = FALSE,
      showticklabels = FALSE,
      showline       = FALSE,
      zeroline       = FALSE,
      range          = xlim
    ),
    yaxis      = list(
      title          = "",
      showgrid       = FALSE,
      showticklabels = FALSE,
      showline       = FALSE,
      zeroline       = FALSE,
      range          = c(getY(bl), getY(ur))
    ),
    showlegend = FALSE
  )

  out$xlim = xlim

  ## Add the edges
  edges <- AgEdge(x)
  edges.p <- list()

  for( i in 1:length(edges) ) {

    edge <- edges[[i]]
    node.to <- edge@head
    node.from <- edge@tail

    for ( j in 1:length(splines(edge)) ) {
      z <- splines(edge)[[j]]
      points <- matrix(unlist(pointList(z)),ncol=2,byrow=TRUE)

      p <- add_trace(
        p,
        x          = points[,1],
        y          = points[,2],
        type       = "scatter",
        mode       = "lines",
        hoverinfo  = "none",
        line       = list(color = "gray"),
        showlegend = FALSE
      )
    }

    edges.p[[i]] <- points

    heads = bezierPoints(z)

    head_from = heads[nrow(heads)-1, ]
    head_to   = heads[nrow(heads),]


  }

  ## Add the nodes
  order <- order(pp[,2],decreasing=TRUE)
  p %<>% plotly::add_trace(
    x          = nodeRI$NODEX[order],
    y          = nodeRI$NODEY[order],
    type       = "scatter",
    mode       = "markers",
    text       = nodeRI$LABEL[order],
    hoverinfo  = "text",
    marker     = list(
      size   = 20,
      symbol = "circle",
      color = cols[order],
      line  = list( color = "black", width = 1)
    ),
    showlegend = FALSE
  )

  out$plot <- p
  out$edges <- edges.p

  return(out)
}

#' map2color
#'
#' @param arg input
#' @export
#' @examples
#' map2color()
#'

map2color <- function(x,pal,limits=NULL){
  if(is.null(limits)) limits=range(x)
  pal[findInterval(
    x,
    seq(limits[1],limits[2],length.out=length(pal)+1),
    all.inside=TRUE
  )]
}


#' trim_tree
#'
#' @param arg input
#' @export
#' @examples
#' trim_tree()
#'

trim_tree <- function(tree = tree, pp = pp, pp.thr = 0.75) {

  idx <- which(pp[,2] < 1 - 0.75)

  t2 <- tree[idx,]
  siblings <- unique(unlist(lapply(t2$ID,get_tree_siblings,tree)))
  paths_to_root <- unique(unlist(lapply(t2$ID,get_path_ids_to_root,tree)))

  nodes_to_keep <- sort(unique(c(t2$ID,siblings,paths_to_root)),decreasing=F)

  t2 <- tree[tree$ID %in% nodes_to_keep, ]
  pp2 <- pp[tree$ID %in% nodes_to_keep,]

  new_id <- 1:nrow(t2)
  new_par <- new_id[match(t2$Par,t2$ID)]

  t2$ID <- new_id
  t2$Par <- new_par

  t2[nrow(t2),'Par'] <- 0
  o <- list(tree=t2,pp=pp2)

  return(o)
}


#' get_tree_siblings
#'
#' @param arg input
#' @export
#' @examples
#' get_tree_siblings()
#'

get_tree_siblings <- function(id,tree) {

  par_id <- tree[ tree$ID %in% id, "Par"]
  sibling_ids <- tree[ tree$Par %in% par_id, "ID"]

  return(sibling_ids)
}


#' get_path_ids_to_root
#'
#' @param arg input
#' @export
#' @examples
#' get_path_ids_to_root()
#'

get_path_ids_to_root <- function(id,tree) {

  out <- id
  root_id <- tree[ nrow(tree), "ID"]

  while( ! root_id %in% out ) {
    out <- unique(c(out,tree[ tree$ID %in% out, "Par"]))
  }

  return(out)
}