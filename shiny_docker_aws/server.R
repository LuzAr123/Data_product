library(shiny)
library(DT)
library(dplyr)
library(rsconnect)
library(tidyverse)
library(ggplot2)
library(readr)


shinyServer(function(input, output, session) {
  
  athlete_events <<- read.csv("https://raw.githubusercontent.com/marcelamelgar/DataProduct/main/ShinyProject/ShinyOlimpics/athlete_events.csv")
  
  #### EVENTOS ####
  output$tablaEventos <- renderDataTable({
    Events <- NULL
    a <- athlete_events%>%
      select(Year,Season,City)
    
    if(!is.null(input$ChooseYear)&!is.null(input$chkboxSeason)){
      Events <- athlete_events%>%
        distinct(City, Year, Season)%>%
        arrange(Year)%>%
        filter(Year >= input$ChooseYear[1] & Year <= input$ChooseYear[2]) %>%
        filter(Season==input$chkboxSeason)
      
      if(nrow(Events)!=0){
        Events%>%
          DT::datatable(rownames = FALSE, filter = "none")
      }}else{a[0,] %>%
          DT::datatable(rownames = FALSE, filter = "none")}
  })
  
  
  observeEvent(input$clean,{
    updateSliderInput(session, 'ChooseYear', value = c(min(athlete_events$Year), max(athlete_events$Year)))
    updateCheckboxGroupInput(session, 'chkboxSeason', choices = unique(athlete_events$Season), selected=NULL, inline = TRUE)
  })
  
  #### EQUIPOS ####
  observe({
    query <- parseQueryString(session$clientData$url_search)
    team <- query[["team"]]
    if(!is.null(team)){
      updateSelectInput(session, "chooseTeam", selected = team)
    }
  })
  
  observe({
    team <- input$chooseTeam
    
    if(session$clientData$url_port==''){
      x <- NULL
    } else {
      x <- paste0(":",
                  session$clientData$url_port)
    }
    
    marcador<-paste0("http://",
                     session$clientData$url_hostname,
                     x,
                     session$clientData$url_pathname,
                     "?","team=",
                     team,'&')
    updateTextInput(session,"url_param",value = marcador)
  })
  
  output$tablaEquipos <- renderDataTable({
    
    
    
    dt <- Equipos %>%
      filter(NOC %in% input$chooseTeam)
    dt
  })
  
  output$plotEquipos <- renderPlot({
    df <- filteredEquipos %>%
      filter(NOC %in% input$chooseTeam)

    ggplot(df, aes(x="", y=participaciones, fill=Sport)) +
      geom_bar(stat="identity", width=1, color="white") +
      coord_polar("y", start=0) +
      ggtitle("Cantidad de Deportes en los que ha participado el equipo")
  })

  
  #### ATLETAS ####
  
  observeEvent(input$season,{
    updateSelectInput(session, "sport",choices = unique(athlete_events[athlete_events$Season%in%input$season,"Sport"]),
                      selected = NULL)
  })
  
  atletas <- reactive({
    sex <<- NULL
    age <<- NULL
    
    if(!is.null(input$season)&!is.null(input$year)&!is.null(input$sport)){
      sex <<- athlete_events%>%
        select(Season,Year,Sport,Sex)%>%
        filter(Season == input$season & Year == input$year & Sport == input$sport)
      
      age <<- athlete_events%>%
        select(Season,Year,Sport,Age)%>%
        filter(Season == input$season & Year == input$year & Sport == input$sport)
    }
  })
  
  
  output$plotSexo <- renderPlot({
    atletas()
    if (nrow(sex)!=0){
      barplot(table(sex$Sex), main = "Cantidad de atletas",
              names.arg = c("Mujeres","Hombres"), col = c("pink","lightblue"),
              horiz = TRUE)
    }
  })
  
  output$plotEdades <- renderPlot({
    atletas()
    if (nrow(age)!=0){
      hist(age$Age, main = "Distribuci??n de edades", 
           xlab = "Edad", col = "lightblue", 
           breaks = seq(min(age$Age), max(age$Age), length.out = 6))
    }
  })
  
  Atletas <- athlete_events %>%
    distinct(ID, Name, Sex,Sport, Team,Age,Games)
  Atletas
  
  countAtletas <- Atletas %>%
    select(Name, Games) %>%
    group_by(Name)%>%
    summarise(participacion = n_distinct(Games))
  countAtletas

  mergedAtletas <-merge(Atletas, countAtletas, by="Name")
  
  output$tablaAtletas <- renderDataTable({
    mergedAtletas %>%
      filter(participacion >= input$ChooseParticipation[1] & participacion <= input$ChooseParticipation[2])%>%
      filter(Sport %in% input$filterSport)%>%
      filter(Team %in% input$filterTeam)%>%
      DT::datatable(options = list(scrollX = TRUE))
  })
  
  output$selectedAtletas <- renderDataTable({
    mergedAtletas[input$tablaAtletas_rows_selected,] %>%
      datatable(extensions = "Buttons", 
                options = list(paging = TRUE,
                               scrollX=TRUE, 
                               searching = TRUE,
                               ordering = TRUE,
                               dom = 'Bfrtip',
                               buttons = c('csv'),
                               pageLength=5, 
                               lengthMenu=c(3,5,10) ))
  })
  
  observeEvent(input$clean2,{
    updatePickerInput(session, 'filterSport', choices = unique(sort(athlete_events$Sport)),options = list(`actions-box` = TRUE))
    updatePickerInput(session, 'filterTeam', choices = unique(sort(athlete_events$Team)),options = list(`actions-box` = TRUE))
    updateSliderInput(session, 'ChooseYear', value = c(min(countAtletas$participacion)), max(countAtletas$participacion))
  })
  
  #### LOGROS ####
  
  medallas <- reactive({
    logros <<- NULL
    if(!is.null(input$year2)&!is.null(input$team2)&!is.null(input$year2)){
      logros <<- athlete_events%>%
        select(Age,Team,Year,Medal,Sex)%>%
        filter(Age >= input$edad2[1]&Age <= input$edad2[2] & Year == input$year2 & Team == input$team2 & !is.na(Medal))%>%
        select(Sex, Medal)%>%
        table()
    }
  })
  
  output$plotlogros <- renderPlot({
    medallas()
    if(nrow(logros)!=0){
      barplot(logros,
              col = c("gray"),
              main = "Medallas obtenidas",
              xlab = "Medalla",
              ylab = "Cantidad",
              legend.text = rownames(logros),
              args.legend = list(x = "topright",
                                 inset = c(-0.1, -0.45)))
    } else {
      output$extra <- renderText(input$clean2)
    }
  })
  
  
  Logros <- athlete_events %>%
    select(Team, NOC, Year, Sport, Event, Medal, Name, ID,Games)
  
  
  archivo_cargado <- reactive({
    contenido_archivo <- input$file_input
    if(is.null(contenido_archivo)){
      return(NULL)
    } else if (grepl('.csv', contenido_archivo$name) ){
      out <- read_csv(contenido_archivo$datapath)
      return(out)
    }
    return(NULL)
  })
  
  output$tablaCargada <- renderDataTable({
    if(!is.null(archivo_cargado())){
      datatable(archivo_cargado())
    }
  })
  
  mergedLogros <- reactive({
    if(!is.null(archivo_cargado())){
      deefe <- merge(Logros, archivo_cargado(), by = c("ID","Name", "Team", "Sport", "Games"))
      return(deefe)
    } else{return(NULL)}
  })
  
  output$tablasoloLogros <- renderDataTable({
    if (!is.null(mergedLogros())){
    df <- mergedLogros() %>%
      select(Name,Team, Sport, Games,Medal)%>%
      DT::datatable()%>%
      formatStyle(columns = "Medal", 
                  background = styleEqual(c('Gold', 'Silver','Bronze'), c("gold", "darkgrey","lightsalmon")))
    df
    }
  })

})


