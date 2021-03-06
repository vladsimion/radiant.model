#######################################
## Simulate data
#######################################

sim_types <- c("Binomial" = "binom","Constant" = "const",
               "Discrete" = "discrete", "Log normal" = "lnorm",
               "Normal" = "norm", "Uniform" = "unif", "Data" = "data",
               "Grid search" = "grid", "Sequence" = "sequ")

sim_args <- as.list(formals(simulater))

## list of function inputs selected by user
sim_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(sim_args))
    sim_args[[i]] <- input[[paste0("sim_",i)]]

  if (!is.null(input$sim_types)) {
    for (i in sim_types)
      if (!i %in% input$sim_types) sim_args[[i]] <- ""
  }

  sim_args
})

rep_args <- as.list(formals(repeater))

## list of function inputs selected by user
rep_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(rep_args))
    rep_args[[i]] <- input[[paste0("rep_",i)]]

  # rep_args[["sim"]] <- paste0(input$sim_name,"_list")
  rep_args[["sim"]] <- input$sim_name

  rep_args

})

rep_sum_args <- as.list(if (exists("summary.repeater")) formals(summary.repeater)
                        else formals(radiant:::summary.repeater))

## list of function inputs selected by user
rep_sum_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(rep_sum_args))
    rep_sum_args[[i]] <- input[[paste0("rep_",i)]]
  rep_sum_args
})

rep_plot_args <- as.list(if (exists("plot.repeater")) formals(plot.repeater)
                         else formals(radiant:::plot.repeater))

## list of function inputs selected by user
rep_plot_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(rep_plot_args))
    rep_plot_args[[i]] <- input[[paste0("rep_",i)]]
  rep_plot_args
})

textinput_maker <- function(id = "const", lab = "Constant", rows = "2", pre = "sim_") {
  id <- paste0(pre, id)
  tags$textarea(state_init(id), id = id, type = "text", rows = rows, class = "form-control")
}

output$ui_sim_types <- renderUI({

  selectizeInput("sim_types", label = "Select types:",
    choices = sim_types, multiple = TRUE,
    selected = state_multiple("sim_types", sim_types),
    options = list(placeholder = 'Select types',
                   plugins = list('remove_button'))
  )
})

output$ui_sim_data <- renderUI({

  choices <- c("None" = "none", r_data$datasetlist)
  selectizeInput(inputId = "sim_data", label = "Input data for calculations:",
    choices = choices,
    selected = state_single("sim_data", choices),
    multiple = FALSE)
})

sim_vars <- reactive({
  if (is_empty(input$sim_name)) {
    character(0)
  } else {
    if (is.null(r_data[[input$sim_name]])) character(0)
    else colnames(r_data[[input$sim_name]])
  }
})

output$ui_rep_vars <- renderUI({
  vars <- sim_vars()
  if (is_empty(vars)) return()

  form <- input$sim_form %>% sim_cleaner
  if (!is_empty(form)) {
    s <- form %>% gsub(" ","",.) %>% sim_splitter("=")
    svars <- c()
    for (i in 1:length(s)) {
      if (grepl("^#",s[[i]][1])) next
      if (grepl(s[[i]][1], s[[i]][2])) next
      svars <- c(svars, s[[i]][1])
    }
    if (length(svars) > 0) vars <- setdiff(vars, svars)
  }

  selectizeInput("rep_vars", label = "Variables to re-simulate:",
    choices = vars, multiple = TRUE,
    selected = state_multiple("rep_vars", vars),
    options = list(placeholder = 'Select variables',
                   plugins = list('remove_button'))
    )
})

output$ui_rep_grid_vars <- renderUI({

  const <- input$sim_const %>% sim_cleaner
  if (const != "") {
    s <- const %>% sim_splitter
    vars <- c()
    for (i in 1:length(s))
      vars <- c(vars, s[[i]][1])
  }

  if (is_empty(vars)) return()

  selectizeInput("rep_grid_vars", label = "Name:",
    choices = vars, multiple = FALSE,
    selected = state_single("rep_grid_vars", vars)
  )
})

output$ui_rep_sum_vars <- renderUI({
  vars <- sim_vars()
  if (is_empty(vars)) return()

  selectizeInput("rep_sum_vars", label = "Output variables:",
    choices = vars, multiple = TRUE,
    selected = state_multiple("rep_sum_vars", vars),
    options = list(placeholder = 'Select variables',
                   plugins = list('remove_button', 'drag_drop'))
    )
})

output$ui_rep_byvar <- renderUI({
  vars <- c("Simulation" = "sim", "Repeat" = "rep")
  selectizeInput("rep_byvar", label = "Group by:", choices = vars,
    selected = state_single("rep_byvar", vars), multiple = FALSE,
    options = list(placeholder = 'Select group-by variable')
  )
})

output$ui_rep_fun <- renderUI({
  choices <-
    list("sum" = "sum_rm", "mean" = "mean_rm", "median" = "median_rm",
         "min" = "min_rm", "max" = "max_rm", "last" = "last", "none" = "none")

  selectInput("rep_fun", label = "Apply function:",
              choices = choices,
              selected = state_single("rep_fun", choices, "sum_rm"),
              multiple = FALSE)
})

var_updater <- function(variable, var_str, var_inputs) {
  if (is.null(variable) || variable == 0) return()
  inp <- paste(var_inputs, collapse = " ")

  if (is_empty(input[[var_str]]))
    val <- paste0(inp, ";")
  else
    val <- paste0(inp, ";\n", input[[var_str]])

  updateTextInput(session = session, var_str, value = val)
}

var_remover <- function(variable) {
  input[[variable]] %>% strsplit("\n") %>% unlist %>% .[-1] %>% paste0(collapse = "\n") %>%
    updateTextInput(session = session, variable, value = .)
}

observeEvent(input$sim_const_add, {
  var_updater(input$sim_const_add, "sim_const", c(input$sim_const_name, input$sim_const_nr))
})

observeEvent(input$sim_sequ_add, {
  var_updater(input$sim_sequ_add, "sim_sequ", c(input$sim_sequ_name, input$sim_sequ_min, input$sim_sequ_max))
})


observeEvent(input$sim_unif_add, {
  var_updater(input$sim_unif_add, "sim_unif", c(input$sim_unif_name, input$sim_unif_min, input$sim_unif_max))
})

observeEvent(input$sim_norm_add, {
  var_updater(input$sim_norm_add, "sim_norm", c(input$sim_norm_name, input$sim_norm_mean, input$sim_norm_sd))
})

observeEvent(input$sim_lnorm_add, {
  var_updater(input$sim_lnorm_add, "sim_lnorm", c(input$sim_lnorm_name, input$sim_lnorm_mean, input$sim_lnorm_sd))
})


observeEvent(input$sim_discrete_add, {
  v <- input$sim_discrete_val
  p <- input$sim_discrete_prob

  v <- gsub(","," ", v) %>% strsplit("\\s+") %>% unlist
  p <- gsub(","," ", p) %>% strsplit("\\s+") %>% unlist

  lp <- length(p); lv <- length(v)
  if (lv != lp && lv %% lp == 0) p <- rep(p, lv / lp)

  var_updater(input$sim_discrete_add, "sim_discrete",
              paste0(c(input$sim_discrete_name, v, p), collapse = " "))
})

observeEvent(input$sim_binom_add, {
  var_updater(input$sim_binom_add, "sim_binom",
              c(input$sim_binom_name, input$sim_binom_n, input$sim_binom_p))
})

observeEvent(input$rep_grid_add, {
  var_updater(input$rep_grid_add, "rep_grid",
              c(input$rep_grid_name, input$rep_grid_min, input$rep_grid_max, input$rep_grid_step))
  updateNumericInput(session = session, "rep_nr", value = NA)
})

observeEvent(input$sim_grid_add, {
  var_updater(input$sim_grid_add, "sim_grid",
              c(input$sim_grid_name, input$sim_grid_min, input$sim_grid_max, input$sim_grid_step))

})

observeEvent(input$sim_grid, {
  if (!is_empty(input$sim_grid)) {
    updateNumericInput(session = session, "sim_nr", value = NA)
  } else {
    val <- ifelse(is_empty(r_state$sim_nr), 1000, r_state$sim_nr)
    updateNumericInput(session = session, "sim_nr", value = val)
  }
})

observeEvent(input$rep_grid, {
  if (!is_empty(input$rep_grid)) {
    updateNumericInput(session = session, "rep_nr", value = NA)
  } else {
    val <- ifelse(is_empty(r_state$rep_nr), 12, r_state$rep_nr)
    updateNumericInput(session = session, "rep_nr", value = val)
  }
})

observeEvent(input$sim_const_del, {
  var_remover("sim_const")
})

observeEvent(input$sim_sequ_del, {
  var_remover("sim_sequ")
})

observeEvent(input$sim_unif_del, {
  var_remover("sim_unif")
})

observeEvent(input$sim_norm_del, {
  var_remover("sim_norm")
})

observeEvent(input$sim_lnorm_del, {
  var_remover("sim_lnorm")
})

observeEvent(input$sim_discrete_del, {
  var_remover("sim_discrete")
})

observeEvent(input$sim_binom_del, {
  var_remover("sim_binom")
})

observeEvent(input$rep_grid_del, {
  var_remover("rep_grid")
})

observeEvent(input$sim_grid_del, {
  var_remover("sim_grid")
})

output$ui_simulater <- renderUI({
  tagList(
    conditionalPanel(condition = "input.tabs_simulate == 'Simulate'",
      wellPanel(
        actionButton("runSim", "Simulate", width = "100%")
      ),
      wellPanel(
        uiOutput("ui_sim_types")
      ),
      ## Using && to check that input.glm_sum_check is not null (must be &&)
      conditionalPanel("input.sim_types && input.sim_types.indexOf('binom') >= 0",
        wellPanel(
          HTML("<label>Binomial variables: <i id='sim_binom_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_binom_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_binom_name", "Name:", value = state_init("sim_binom_name", ""))),
              td(numericInput("sim_binom_n", "n:", value = state_init("sim_binom_n"), min = 1)),
              td(numericInput("sim_binom_p", "p:", value = state_init("sim_binom_p"), min = 0))
            )
          ),
          textinput_maker("binom","Binomial")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('const') >= 0",
        wellPanel(
          HTML("<label>Constant variables: <i id='sim_const_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_const_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_const_name", "Name:", value = state_init("sim_const_name", ""))),
              td(numericInput("sim_const_nr", "Value:", value = state_init("sim_const_nr")))
            )
          ),
          textinput_maker("const","Constant")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('discrete') >= 0",
        wellPanel(
          HTML("<label>Discrete variables: <i id='sim_discrete_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_discrete_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_discrete_name", "Name:", value = state_init("sim_discrete_name", ""))),
              td(textInput("sim_discrete_val", "Values:", value = state_init("sim_discrete_val"))),
              td(textInput("sim_discrete_prob", "Prob.:", value = state_init("sim_discrete_prob")))
            )
          ),
          textinput_maker("discrete","Discrete")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('lnorm') >= 0",
        wellPanel(
          HTML("<label>Log-normal variables: <i id='sim_lnorm_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_lnorm_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_lnorm_name", "Name:", value = state_init("sim_lnorm_name", ""))),
              td(numericInput("sim_lnorm_mean", "Mean:", value = state_init("sim_lnorm_mean"))),
              td(numericInput("sim_lnorm_sd", "St.dev.:", value = state_init("sim_lnorm_sd"), min = 1))
            )
          ),
          textinput_maker("lnorm","Log normal")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('norm') >= 0",
        wellPanel(
          HTML("<label>Normal variables: <i id='sim_norm_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_norm_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_norm_name", "Name:", value = state_init("sim_norm_name", ""))),
              td(numericInput("sim_norm_mean", "Mean:", value = state_init("sim_norm_mean"))),
              td(numericInput("sim_norm_sd", "St.dev.:", value = state_init("sim_norm_sd"), min = 0))
            )
          ),
          textinput_maker("norm","Normal")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('unif') >= 0",
        wellPanel(
          HTML("<label>Uniform variables: <i id='sim_unif_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_unif_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_unif_name", "Name:", value = state_init("sim_unif_name", ""))),
              td(numericInput("sim_unif_min", "Min:", value = state_init("sim_unif_min"))),
              td(numericInput("sim_unif_max", "Max:", value = state_init("sim_unif_max")))
            )
          ),
          textinput_maker("unif","Uniform")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('sequ') >= 0",
        wellPanel(
          HTML("<label>Sequence variables: <i id='sim_sequ_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_sequ_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_sequ_name", "Name:", value = state_init("sim_sequ_name", ""))),
              td(numericInput("sim_sequ_min", "Min:", value = state_init("sim_sequ_min"))),
              td(numericInput("sim_sequ_max", "Max:", value = state_init("sim_sequ_max")))
            )
          ),
          textinput_maker("sequ","Sequence")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('grid') >= 0",
        wellPanel(
          HTML("<label>Grid search: <i id='sim_grid_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='sim_grid_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("sim_grid_name", "Name:", value = state_init("sim_grid_name", ""))),
              td(numericInput("sim_grid_min", "Min:", value = state_init("sim_grid_min"))),
              td(numericInput("sim_grid_max", "Max:", value = state_init("sim_grid_max"))),
              td(numericInput("sim_grid_step", "Step:", value = state_init("sim_grid_step")))
          )),
          textinput_maker("grid")
        )
      ),
      conditionalPanel("input.sim_types && input.sim_types.indexOf('data') >= 0",
        wellPanel(
          uiOutput("ui_sim_data")
        )
      ),
      wellPanel(
        with(tags, table(
          td(numericInput("sim_seed", "Set random seed:",
                       value = state_init("sim_seed", 1234))),
          td(numericInput("sim_nr", "# sims:", min = 1, max = 10^6,
                          value = state_init("sim_nr", 1000)))
        )),
        with(tags, table(
          td(textInput("sim_name", "Simulated data:", state_init("sim_name", "simdat"))),
          td(numericInput("sim_dec", label = "Decimals:", value = state_init("sim_dec", 4), min = 0, width = "80px"))
        )),
        checkboxInput("sim_show_plots", "Show plots", state_init("sim_show_plots",FALSE))
      ),
      help_and_report(modal_title = "Simulate", fun_name = "simulater",
        help_file = inclMD(file.path(getOption("radiant.path.model"),"app/tools/help/simulater.md")))
    ),
    conditionalPanel(condition = "input.tabs_simulate == 'Repeat'",
      wellPanel(
        actionButton("runRepeat", "Repeat", width = "100%")
      ),
      wellPanel(
        uiOutput("ui_rep_vars"),
        uiOutput("ui_rep_sum_vars")
      ),
      wellPanel(
        uiOutput("ui_rep_byvar"),
        conditionalPanel(condition = "input.rep_byvar == 'rep'",
          HTML("<label>Grid search: <i id='rep_grid_add' title='Add variable' href='#' class='action-button fa fa-plus-circle'></i>
                <i id='rep_grid_del' title='Remove variable' href='#' class='action-button fa fa-minus-circle'></i></label>"),
          with(tags, table(
              td(textInput("rep_grid_name", "Name:", value = state_init("rep_grid_name", ""))),
              td(numericInput("rep_grid_min", "Min:", value = state_init("rep_grid_min"))),
              td(numericInput("rep_grid_max", "Max:", value = state_init("rep_grid_max"))),
              td(numericInput("rep_grid_step", "Step:", value = state_init("rep_grid_step")))
          )),
        textinput_maker("grid","",pre = "rep_")
        ),
        uiOutput("ui_rep_fun")
      ),
      wellPanel(
        with(tags, table(
          td(numericInput("rep_seed", "Set random seed:",
                       value = state_init("rep_seed", 1234))),
          td(numericInput("rep_nr", "# reps:", min = 1, max = 10^6,
                          value = state_init("rep_nr", 12)))
          )
        ),
        with(tags, table(
          td(textInput("rep_name", "Repeat data:", state_init("rep_name", "repdat"))),
          td(numericInput("rep_dec", label = "Decimals:", value = state_init("rep_dec", 4), min = 0, max = 10, width = "80px"))
        )),
        checkboxInput("rep_show_plots", "Show plots", state_init("rep_show_plots",FALSE))
      ),
      help_and_report(modal_title = "Repeat simulation", fun_name = "repeater",
                      help_file = inclMD(file.path(getOption("radiant.path.model"),"app/tools/help/simulater.md")))
    )
  )
})

## output is called from the main radiant ui.R
output$simulater <- renderUI({

    register_print_output("summary_simulate", ".summary_simulate")
    register_plot_output("plot_simulate", ".plot_simulate",
                          width_fun = "sim_plot_width",
                          height_fun = "sim_plot_height")

    register_print_output("summary_repeat", ".summary_repeat")
    register_plot_output("plot_repeat", ".plot_repeat",
                          width_fun = "rep_plot_width",
                          height_fun = "rep_plot_height")

    ## mulitple tabs with components stacked
    sim_output_panels <- tabsetPanel(
      id = "tabs_simulate",
      tabPanel("Simulate",
        HTML("<label>Simulation formulas:</label>"),
        textinput_maker("form","Formula", rows = "5"),
        HTML("</br><label>Simulation summary:</label>"),
        verbatimTextOutput("summary_simulate"),
        HTML("</br><label>Simulation plots:</label>"),
        plotOutput("plot_simulate", height = "100%")
      ),
      tabPanel("Repeat",
        HTML("<label>Repeated simulation formulas:</label>"),
        textinput_maker("form","Rformula", rows = "3", pre = "rep_"),
        HTML("</br><label>Repeated simulation summary:</label>"),
        verbatimTextOutput("summary_repeat"),
        HTML("</br><label>Repeated simulation plots:</label>"),
        plotOutput("plot_repeat", height = "100%")
      )
    )

    stat_tab_panel(menu = "Model > Decide",
                   tool = "Simulate",
                   data = NULL,
                   tool_ui = "ui_simulater",
                   output_panels = sim_output_panels)
})

.simulater <- eventReactive(input$runSim, {
  withProgress(message = "Running simulation", value = 1, {
    do.call(simulater, sim_inputs())
  })
})

.summary_simulate <- eventReactive(input$runSim, {
  summary(.simulater(), dec = input$sim_dec)
})

sim_plot_width <- function() 650
sim_plot_height <- function() {
  sim <- .simulater()
  if (is.character(sim)) {
    if (sim[1] == "error") return(300)
    sim <- getdata(sim)
    if (dim(sim)[1] == 0) {
      300
    } else {
      ceiling(sum(sapply(sim, does_vary)) / 2) * 300
    }
  } else {
    300
  }
}

.plot_simulate <- reactive({
  req(input$sim_show_plots)
  withProgress(message = "Generating simulation plots", value = 1, {
    .simulater() %>% { if (is_empty(.)) invisible() else plot(., shiny = TRUE) }
  })
})

.repeater <- eventReactive(input$runRepeat, {
  withProgress(message = "Running repeated simulation", value = 1, {
    do.call(repeater, rep_inputs())
  })
})

.summary_repeat <- eventReactive(input$runRepeat, {
  if (length(input$rep_sum_vars) == 0)
    return("Select at least one Output variable")
  summary(.repeater(), dec = input$rep_dec)
})

rep_plot_width <- function() 650
rep_plot_height <- function() {
  if (length(input$rep_sum_vars) == 0) return(300)
  rp <- .repeater()
  if (is.character(rp)) {
    if (rp[1] == "error") return(300)
    rp <- getdata(rp)
    if (dim(rp)[1] == 0) {
      300
    } else {
      ceiling(sum(sapply(select(rp,-1), does_vary)) / 2) * 300
    }
  } else {
    300
  }
}

.plot_repeat <- reactive({
  req(input$rep_show_plots)
  req(length(input$rep_sum_vars) > 0)
  object <- .repeater()
  if (is.null(object)) return(invisible())
  withProgress(message = "Generating repeated simulation plots", value = 1, {
    rep_plot_inputs() %>% { .$shiny <- TRUE; . } %>%
      { do.call(plot, c(list(x = object), .)) }
  })
})

report_cleaner <- function(x) x %>% gsub("\n",";",.) %>% gsub("[;]{2,}",";",.)

observeEvent(input$simulater_report, {
  sim_dec <- input$sim_dec %>% {ifelse(is_not(.), 3, .)}
  outputs <- "summary"
  inp_out <- list(list(dec = sim_dec), "")
  figs <- FALSE

  if (isTRUE(input$sim_show_plots)) {
    outputs <- c("summary", "plot")
    inp_out[[2]] <- list(custom = FALSE)
    figs <- TRUE
  }

  ## report cleaner turns seed and nr into strings
  inp <- clean_args(sim_inputs(), sim_args) %>% lapply(report_cleaner)
  if (!is_empty(inp$seed)) inp$seed <- as_numeric(inp$seed)
  if (!is_empty(inp$nr)) inp$nr <- as_numeric(inp$nr)

  update_report(inp_main = inp,
                fun_name = "simulater", inp_out = inp_out,
                outputs = outputs, figs = figs,
                fig.width = sim_plot_width(),
                fig.height = sim_plot_height())
})

observeEvent(input$repeater_report, {
  rep_dec <- input$rep_dec %>% {ifelse(is_not(.), 3, .)}
  outputs <- "summary"
  inp_out <- list(list(dec = rep_dec), "")
  figs <- FALSE

  if (isTRUE(input$rep_show_plots)) {
    outputs <- c("summary", "plot")
    inp_out[[2]] <- list(custom = FALSE)
    figs <- TRUE
  }

  ## report cleaner turns seed and nr into strings
  inp <- clean_args(rep_inputs(), rep_args) %>% lapply(report_cleaner)
  if (!is_empty(inp$seed)) inp$seed <- as_numeric(inp$seed)
  if (!is_empty(inp$nr)) inp$nr <- as_numeric(inp$nr)

  update_report(inp_main = inp,
                fun_name = "repeater", inp_out = inp_out,
                outputs = outputs, figs = figs,
                fig.width = rep_plot_width(),
                fig.height = rep_plot_height())
})
