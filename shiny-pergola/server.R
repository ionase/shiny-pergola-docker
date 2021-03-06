############################################################################################
### Jose A Espinosa. NPMMD/CB-CRG Group. Jan 2017                                        ###
############################################################################################
### Shiny app to show pergola data using Gviz                                            ###
### server.R                                                                             ###
############################################################################################
### TODO                                                                                 ###
### Benchmark using system.time, benchmark library                                       ###
### Try to load plots at the beginning less time                                         ### 
############################################################################################
# local installation of the library
# devtools::with_libpaths(new ="/users/cn/jespinosa/R/library", devtools::install_github("JoseEspinosa/Gviz"))

options(warn=1)

library(GenomicRanges)
library (rtracklayer)
library(ggplot2)
library(grid)
library (gridExtra)

## line to be deleted only for loading library on crg ant
{
  if (file.exists("/users/cn/jespinosa")) {
    library ("Gviz", lib="/users/cn/jespinosa/R/library")
  }
  else {
    library(Gviz)
  }
}

## Extract Legend 
g_legend <- function(a.gplot){ 
  tmp <- ggplot_gtable(ggplot_build(a.gplot)) 
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box") 
  legend <- tmp$grobs[[leg]] 
  return(legend)} 

avail_plots <- c("plot_int", "plot_heat", "plot_gr")
col_back_title="brown"
tr_phase_size <- 2
tr_gr_size <- 10
lab_group_plot <- "Mean intake (grams)"
name_phases_tr <- "Phases"
color_min <- 'white'
color_max <- 'blue'
phases_color <- 'gray'

col_gr_1 <- "darkblue"
col_gr_2 <- "brown"
col_ctrl <- col_gr_1
col_case <- col_gr_2
cb_palette <- c("#999999", "#E69F00", "#56B4E9",
                "#009E73", "#F0E442", "#0072B2", 
                "#D55E00", "#CC79A7", "#000000", 
                "#00009B")

## Avoid problems if user set many groups
cb_palette <- rep (cb_palette, 10) 

## show legend
leg_bool <- FALSE
# size_text_leg <- 12
size_text_leg <- 14

base_dir <- "/pergola_data"
data_dir <- file.path(base_dir, "files")

exp_design_f <- "exp_info.txt"

b2v <- exp_info <- read.table(file.path(base_dir, exp_design_f), header = TRUE, stringsAsFactors=FALSE)

{ 
  if (length(exp_info$sample) != length(unique(exp_info$sample))) {
    stop ("Sample names duplicated in configuration file")}
}

perg_bed_files <- sapply(exp_info$sample, function(id) file.path(data_dir, paste(id, ".bed", sep="")))

# exp_info <- read.table(file.path(base_dir, "exp_info.txt"), header = TRUE, stringsAsFactors=FALSE)
b2v <- dplyr::mutate(b2v, path = perg_bed_files, header = TRUE, stringsAsFactors=FALSE)


perg_bedg_files <- sapply(exp_info$sample, function(id) file.path(data_dir, paste(id, ".bedGraph", sep="")))

bg2v <- exp_info <- read.table(file.path(base_dir, exp_design_f), header = TRUE, stringsAsFactors=FALSE)
bg2v <- dplyr::mutate(bg2v, path = perg_bedg_files)

g_min_start <- 100000000
g_max_end <- -100000000
min_v <- 0
max_v <- 0

l_gr_color <- mapply(function(x, col) list(col),
                     unique(b2v$condition), 
                     cb_palette[1:length(unique(b2v$condition))])

bed2pergViz <- function (data_df, gr_df, format_f="BED") {
  grps <- as.character(gr_df[[setdiff(colnames(gr_df), 'sample')]])
  
  r <- lapply(unique(grps),
              function(g) {
                gr_samps <- grps %in% g
                gr_files <- data_df$path[gr_samps]
                
                lapply(gr_files, function (bed) {             
                  id <- gsub(".+tr_(\\d+)(_.+$)", "\\1", bed)
                  bed_GR <- import(bed, format = format_f)
                  min_start <- min(start(bed_GR))
                  max_end <- max(end(bed_GR))
                  
                  if (format_f == "BED") {                              
                    tr <- AnnotationTrack(bed_GR, name = paste ("", id, sep=""),
                                          fill=l_gr_color[[g]], 
                                          background.title = l_gr_color[[g]], col=NULL)#, fill=col_ctrl, background.title = col_ctrl)               
                  }
                  
                  if (format_f == "bedGraph") {
                    min_v <<- floor (min(bed_GR$score))
                    max_v <<- ceiling (max(bed_GR$score))
                    #                scores <- as.vector(mcols(bed_GR))
                    #                tr <- DataTrack(bed_GR, name = paste ("", id, sep=""))#, fill=col_ctrl, background.title = col_ctrl)               
                    tr <- bed_GR
                  }
                  
                  if (g_min_start > min_start) { g_min_start <<- min_start }
                  if (g_max_end < max_end) { g_max_end <<- max_end }
                  
                  return (tr) })
              })
  
  names(r) <- unique(grps)
  return (r)
}

l_gr_annotation_tr_bed <- bed2pergViz (b2v, exp_info)

phases_file <- file.path(data_dir, "phases_dark.bed")

l_granges_bg <- bed2pergViz (bg2v, exp_info, "bedGraph") 

{ 
  if(file.exists(phases_file)) {
    bed_phases <- import(phases_file, format = "BED")
    phases_tr <- AnnotationTrack(bed_phases, name = paste ("", name_phases_tr, sep=""),
                                 fill = phases_color, #rotation.title=1, #cex.sampleNames = 0.1, #size = tr_phase_size,                                
                                 background.title = col_back_title, col=NULL)    
  }
  else {
    phases_tr <- NULL
  }
}

g_min_data = min(g_min_start, 1000)
g_max_data = max(g_max_end, 1000000)
step_dataInt <- 1000

data_interval <- g_max_end - g_min_start

# By default 5 % of the data is displayed   
step_ten_per_cent <- 0.05 * data_interval 

## IDs for exactly reproduce paper figures
{
  if (file.exists(file.path(base_dir, "id.txt"))) {
    l = readLines(file.path(base_dir, "id.txt"))
    if (l == "cb1_a") {
      min_data_int <- 1 
      max_data_int <- 3628800 #6 weeks
      min_heatmap <- 0
      max_heatmap <- 0.5
      def_avail_plots <- avail_plots
    }
    else if (l == "cb1_b") {
      #       min_data_int <- 1555200
      min_data_int <- 2592000 #day 30
      #       max_data_int <- 2160000
      max_data_int <- 3456000 #day 40
      min_heatmap <- 0
      max_heatmap <- 0.3
      def_avail_plots <- avail_plots
    }
    else if (l == "cb1_c") {
      # day 6-7
      #       min_data_int <- 518400 
      #       max_data_int <- 691200 
      # day 33 -34
      min_data_int <- 2851200
      max_data_int <- 3024000
      min_heatmap <- 0
      max_heatmap <- 0.3
      def_avail_plots <- avail_plots[2]
    }
    ###############
    ## hf data 2018
    else if (l == "hf_s3") {
      # all period (9 weeks)
      min_data_int <- 26953
      max_data_int <- 5443200+26953
      min_heatmap <- 0
      max_heatmap <- 4
      def_avail_plots <- avail_plots
    }
    else if (l == "hf_s4a") {
      # habituation week
      min_data_int <- 26953
      max_data_int <- 604800+26953
      min_heatmap <- 0
      max_heatmap <- 0.5
      def_avail_plots <- avail_plots[1:2]
    }
    else if (l == "hf_s4b") {
      # 3 first weeks
      min_data_int <- 26953
      max_data_int <- 1814400+26953 #1841353
      min_heatmap <- 0
      max_heatmap <- 0.5
      def_avail_plots <- avail_plots[1:2]
    }
    else if (l == "hab_to_dev") {
      # transition from hab to dev
      # day 5 to 9
      min_data_int <- 26953 + 432000
      max_data_int <- 26953 + 777600
      min_heatmap <- 0
      max_heatmap <- 2
      def_avail_plots <- avail_plots
    }
    else {
      min_data_int <- min(g_min_start, 1000)
#       max_data_int <- g_min_start + 10000
      max_data_int <- g_min_start + step_ten_per_cent
      min_heatmap <- 0
      max_heatmap <- 0.5
      def_avail_plots <- avail_plots[1:2]
    }
    
  }
  else {
    min_data_int <- min(g_min_start, 1000)
#     max_data_int <- g_min_start + 10000
    max_data_int <- g_min_start + step_ten_per_cent
    min_heatmap <- 0
    max_heatmap <- 0.5
    def_avail_plots <- avail_plots[1:2]
  }
}

l_gr_data_tr_bg_tmp <- lapply (seq_along(l_granges_bg), function (i_group_exp) {
  lapply (seq_along (l_granges_bg[[i_group_exp]]),  function (i_track) {                                                     
    granges_obj <-l_granges_bg[[i_group_exp]][[i_track]]
    tr_name <- names(l_granges_bg[[i_group_exp]][i_track])                                                     
    id <- gsub("^tr_(\\d+)(_dt.*$)", "\\1", tr_name)                                                     
    d_track <- DataTrack(granges_obj,
                         type="heatmap", ylim = c(min_heatmap, max_heatmap),
                         background.title = l_gr_color[[i_group_exp]],
                         gradient=c(color_min, color_max), 
                         showAxis = F, name = id)
    return (d_track)
  })
})

names (l_gr_data_tr_bg_tmp) <- names(l_granges_bg)
l_gr_data_tr_bg <-l_gr_data_tr_bg_tmp
l_gr_annotation_tr_bg <- l_gr_data_tr_bg
list_all_bg <- l_gr_data_tr_bg

l_all_common_int <- list() 
common_intervals <- Reduce(subsetByOverlaps, c(unlist (l_granges_bg))) 

l_gr_annotation_tr_bg <- l_granges_bg

group_lab <- unlist(lapply (seq_along(l_granges_bg), function (i_group_exp) {
  rep (names(l_granges_bg[i_group_exp]), length(l_granges_bg[[i_group_exp]])) 
}))
#####
## Problem with order of colors, the colors are not set by the provided order by the
## alphabetical order of the groups label, for instance if we have control and case
## the case color will be the first on the col assignment 
group_lab <- factor(group_lab, levels = unique(group_lab))
color_by_tr <- unlist(l_gr_color[unique(group_lab)])

l_all_common_int <- sapply(unlist(l_gr_annotation_tr_bg), 
                           function (l, common_GR=common_intervals) { 
                             mcol <- mcols(subsetByOverlaps (l, common_intervals)) 
                             return (mcol)
                             #                             return (data.frame(mcol))
                           })

df_common_int <- as.data.frame (unlist(l_all_common_int))

## This was not working problably because number of rows was not correctly set
# df_common_int <- data.frame(matrix(unlist(l_all_common_int), nrow=length(common_intervals), byrow=T))
# names(df_common_int) <- paste ("id_", gsub(".+tr_(\\d+)(_.+$)", "\\1", names (unlist(l_gr_annotation_tr_bg))), sep="")
id <- gsub(".+tr_(\\d+)(_.+$)", "\\1", names (unlist(l_gr_annotation_tr_bg)))
data_type <- gsub(".+tr_(\\d+)_dt_(\\w+._.+$)", "\\2", names (unlist(l_gr_annotation_tr_bg)))
names(df_common_int) <- paste ("id", id, data_type, sep="_")
                               
gr_common_intervals <- GRanges()
gr_common_intervals <- common_intervals
mcols(gr_common_intervals) <- df_common_int

g_tr <- GenomeAxisTrack()
x <- runif(length(l_gr_color),0,100)
y <- runif(length(l_gr_color),100,200)

df_legend <- data.frame(x, y, unique(group_lab))
colnames(df_legend) <- c("x", "y", "names")

df_empty <- data.frame()

n_tracks <- length(exp_info$sample)

v_size_font <- switch(as.character(round(n_tracks/10)),
                      "0"=c(20,0.5),
                      "1"=c(14,0.6),
                      "2"=c(14,0.6),
                      "3"=c(12,0.7),
                      "4"=c(6,1),
                      "5"=c(6,1),
                      "6"=c(6,1),
                      "7"=c(6,1),
                      "8"=c(6,1),
                      "9"=c(6,1),
                      "10"=c(6,1),
                      c(12,0.7))

size_labels <- v_size_font [1]
cex_gtrack <- v_size_font [2]
  
shinyServer(function(input, output) {
  output$bedGraphRange_tab <- renderUI({
    sliderInput("bedGraphRange", label = h4("Data range:"), 
                min = min_v, max = max_v, 
                value = c(min_heatmap, max_heatmap), 
                step= 0.1)
  })
  output$dataInterval_tab <- renderUI({
    sliderInput("dataInterval", label = h4("Data interval:"), 
                min = g_min_data,
                max = g_max_data,
                value = c(min_data_int, max_data_int),
                step= step_dataInt) 
  }) 
  output$plots2show_tab <- renderUI({
    checkboxGroupInput( "plots2show", label = h4("Plots to display:"),
                        choices = c("Intervals" = avail_plots[1], 
                                    "Heatmap" = avail_plots[2], 
                                    "Groups mean" = avail_plots[3] ), 
                        selected = def_avail_plots)
  })
  output$groups_tab <- renderUI({
    checkboxGroupInput( "groups", label = h4("Groups to render:"), 
                        choices = unique(group_lab), 
                        selected=unique(group_lab))
  })
  output$type_gr_plot_tab <- renderUI({
    if (!"plot_gr" %in% input$plots2show) {
      return ()
    }
    else {
      return (selectInput("type_gr_plot", label = h4("Group plot type:"),
                          choices = list("Lines plot" = "a", "Boxplot" = "boxplot", "Confint" = "confint"), 
                          selected = "a"))
    }     
  })
  size_img <- reactive ({
    length(input$plots2show) * 15
  })
  groups_dt <- reactive({
    #     if(!is.null(input$groups_plot) && input$groups_plot == TRUE) {
    
    gr_common_intervals_subset <- gr_common_intervals [ , group_lab %in% input$groups] 
    
    common_bedg_dt <- DataTrack(gr_common_intervals_subset, name = lab_group_plot, type = input$type_gr_plot,
                                showSampleNames = TRUE, #ylim = c(0, 0.5),                                     
                                groups = group_lab[group_lab %in% input$groups], col = color_by_tr,
                                background.title = col_back_title, #size = tr_gr_size,
                                legend = leg_bool)
    
    common_bedg_dt
  })
  
  # Render variables to see content 
  #   output$text1 <- renderText({ 
  #     paste(as.character ("test", input$type_gr_plot))
  #   })
  
  all_plot <- reactive({
    if(length(input$bedGraphRange)==0){
      return(NULL)
    }
    else {
      withProgress(message = 'Rendering plot', style = 'notification', value = 0.1, {
        plots2show_bool <- avail_plots %in% input$plots2show
        list_plots <- c(g_tr)
        incProgress(0.1)
        # Appending the plots if selected
        if (plots2show_bool[1] == TRUE) {
          list_plots <- c(list_plots, unlist(l_gr_annotation_tr_bed[input$groups]))
        }
        
        if (plots2show_bool[2] == TRUE) {
          list_plots <- c(list_plots, unlist(list_all_bg[input$groups]))
        }
        
        if (plots2show_bool[3] == TRUE) {
          list_plots <- c(list_plots,  groups_dt())
        }
        
        # Load phases track when present 
        # Always last plot
        list_plots <- c(list_plots,  phases_tr) 
        
        pt <- plotTracks(list_plots,
                         from=input$dataInterval[1], to=input$dataInterval[2], 
                         ylim=c(input$bedGraphRange[1], input$bedGraphRange[2]),                                                     
                         shape = "box", stacking = "dense", fontsize=size_labels, cex=cex_gtrack)
        pt
        incProgress(0.9)
      }) 
    }
  })

  legend_joined <- reactive ({
   
      plots2show_bool <- avail_plots %in% input$plots2show
      
      plot_legends <- plot_empty <- ggplot(df_empty) + 
                      geom_point() + 
                      theme(panel.border = element_blank(), panel.background = element_blank())
                  
      # Appending the legends plots if selected
      if (plots2show_bool[1] == TRUE || plots2show_bool[3] == TRUE) {
        plot_legends <- plot_legends + geom_point(data=df_legend, aes(x=x, y=y, colour = names), shape=15, size=5) +
          scale_colour_manual (values=color_by_tr) + guides(color=guide_legend(title=NULL)) + 
          theme(legend.position="bottom", legend.justification=c(1, 0), legend.text=element_text(size=size_text_leg),
                legend.key = element_rect(fill = "white", colour = "white")) + geom_blank()
      }
      
      if (plots2show_bool[2] == TRUE) {
        plot_legends <- plot_legends + geom_point(data=df_legend, aes(x=x, y=y, fill = 0)) +
          scale_fill_gradientn (guide = "colorbar",
                                colours = c(color_min, color_max),
                                values = c(input$bedGraphRange[1], input$bedGraphRange[2]),
                                limits = c(input$bedGraphRange[1], input$bedGraphRange[2]),
                                breaks   = c(input$bedGraphRange[1], input$bedGraphRange[2]),
                                labels = c(input$bedGraphRange[1], paste(input$bedGraphRange[2],"    ", sep="")),
                                name = "",
                                rescaler = function(x,...) x,                                        
                                oob = identity) + theme (legend.position = "none") + 
          theme(legend.position="bottom", legend.justification=c(1,0), legend.text=element_text(size=size_text_leg)) +
          geom_blank()  
      }
      legend_joined <- g_legend (plot_legends)
  })
  
  output$plotbed <- renderPlot({
    
    all_plot()
    
  })
  
  output$legend_track <- renderPlot({
    ## empty plot 
    grid.newpage()
    plot_empty <- ggplot(df_empty) + 
      geom_point() + 
      theme(panel.border = element_blank(), panel.background = element_blank())
    
#     grid.draw(leg_heatmap ())
#     grid.draw(leg_group ())
    if (!is.null(input$plots2show)) {
      grid.draw(legend_joined())
    }
  })
  
  output$all_plot_tiff <- downloadHandler(
    filename <-  'tracks_plot.tiff' ,
    content <- function(file) {
      ## TODO size should be link to the number of tracks in the rendering
      #     tiff(file)
      tiff(file, height = size_img(), width = size_img()*3/4, units = 'cm', res = 300)
      #     tiff(file, height=30, width = 16, units = 'cm', res=300)#height = 12, width = 17, units = 'cm'
      
      if(length(input$bedGraphRange)==0){
        return(NULL)
      }
      else {
          
          plots2show_bool <- avail_plots %in% input$plots2show
          list_plots <- c(g_tr)
          
          # Appending the plots if selected
          if (plots2show_bool[1] == TRUE) {
              list_plots <- c(list_plots, unlist(l_gr_annotation_tr_bed[input$groups]))
          }
          
          if (plots2show_bool[2] == TRUE) {
              list_plots <- c(list_plots, unlist(list_all_bg[input$groups]))
          }
          
          if (plots2show_bool[3] == TRUE) {
              list_plots <- c(list_plots,  groups_dt())
          }
          
          # Load phases track when present 
          # Always last plot
          list_plots <- c(list_plots,  phases_tr) 
          
          pt <- plotTracks(list_plots,
                           from=input$dataInterval[1], to=input$dataInterval[2], 
                           ylim=c(input$bedGraphRange[1], input$bedGraphRange[2]),                                                      
                           shape = "box", stacking = "dense", fontsize=size_labels, cex=cex_gtrack)
          pt 

      }
      
      dev.off()
    })
})
