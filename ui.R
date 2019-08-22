##===========================================================================##
## /  /  /  /  /  /  /  /  AA /  /  /QQQQQ/  /  /  /  /  /  /  /  /  /  /  / ##
##/  /  /  /  /  /  /  /  AAAA  /  /QQ/  QQ /  /  /  /  /  /  /  /  /  /  /  ##
##  /  /  /  /  /  /  /  AA /AA/  /QQ/  / QQ  /  /  /  /  /  /  /  /  /  /  /##
## /  /  /  /  /  /  /  /AA/ AA  /QQ/  /  /QQ/  /  /  /  /  /  /  /  /  /  / ##
##/  /  /  /  /  /  /  /AAAAAAAA/ QQ  /  / QQ  /  /  /  /  /  /  /  /  /  /  ##
##  /  /  /  /  /  /  / AAAAAAAA  /QQ/  /QQQ  /  /  /  /  /  /  /  /  /  /  /##
## /  /  /  /  /  /  /  AA /  AA /  QQ / QQQQ/  /  /  /  /  /  /  /  /  /  / ##
##/  /  /  /  /  /  /  /AA/  /AA/  / QQQQQ QQQ /DASHBOARD  /  /  /  /  /  /  ##
##  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /##
## /  /  /  /  /  /  /  /  /  /  /  /UI.R /  /  /  /  /  /  /  /  /  /  /  / ##
##---------------------------------------------------------------------------##
## \  \  \  \  \  \  \  \ Written by AJB, Ph.D in 2018\  \  \  \  \  \  \  \ ##
##---------------------------------------------------------------------------##
##                                   OVERVIEW                                ##
## This file runs before the server.R file. It controls the structure of the ##
## dashboard's user interface (UI). Additionally, it runs before the         ##
## server.R file, so all global options settings and packages need to be set ##
## and loaded at the top of this file.                                       ##
##---------------------------------------------------------------------------##
##                          STRUCTURE OF THIS DOCUMENT                       ##
## This document contains the following sections:                            ##
##   1.) Options and libraries: Sets global options pertaining to R and      ##
##       Java as well as loading the proper packages. Note that all packages ##
##       and their dependencies must be installed for the dashboard to run.  ##
##   2.) Report/Control functions: Contains functions that render the        ##
##       necesasry HTML for displaying the "shell" of the dashboard. All     ##
##       tables and charts are built in server.R and output back to this     ##
##       file, where they are displayed in the proper location. See the      ##
##       [typeofelement]Output parts of those functions to identify what is  ##
##       being rendered there.                                               ##
##   3.) CSS stylesheet: A very messy stylesheet that customizes the styling ##
##       of the dashboard. Contains several class definitions as well.       ##
##   4.) The UI function: This function is the outer shell of the dasbhoard. ##
##       The basic structure (as well as head and header information) are    ##
##       contained here.                                                     ##
##===========================================================================##

{
## This parameter ups the R's memory allocation for Java. This is deceptively
## important. Because the EDW is Java-based (JDBC) and some of the predictive
## model datasets are very large, not upping this limit will often result in
## the dashboard crashing with only a vague warning. The second option
## suppresses warning messages. Although this is commonly considered a bad
## idea, I do so here because the desktop version of the dashboard produces
## error logs, and plotly throws an obscene number of warning messages as it's
## a bit more verbose than it needs to be.
  
## Note that all options and packages for shiny applications should be put at
## the top of the ui.R file as they are here.
options(java.parameters = c("-Xmx12000m", "-XX:-UseGCOverheadLimit"),
        warn = -1
)
library(shiny)
library(shinyjs)
library(shiny.semantic)
library(plotly)
library(flexdashboard)
library(DT)
# library(zoo)
library(dplyr)
library(tidyr)
library(RMySQL)
library(RJDBC)
library(mirt)
library(mirtCAT)
library(car)
library(shinycssloaders)
library(quantmod)
library(shinyWidgets)
library(shinyjqui)
library(rintrojs)
library(timevis)
library(rmarkdown)
library(knitr)
library(htmltools)
library(webshot)
library(shinycustomloader)
library(RPostgres)
} # options and libraries

{
## Similar to the form of the server.R file, I've opted to write much of the
## code in a series of optionless functions. Due to shiny's error tracing
## conventions, using functions makes it much easier to pinpoint problems
## while debugging the server.R file. For this file, it's merely more
## convenient for styling complex UI elements, then simply dropping them in the
## semanticPage part of this syntax.
  
## Styling and layout for the sidebar on the left-hand side of the dashboard.
## reactive and interactive content is governed by the sidebarSC, sidebarMob,
## and sidebarCog and a pair of event handlers pertaining to the swallowing
## (self-care) and wheelchair (mobility) assessment areas.
sidebar <- function(){
  div(class = 'ui sidebar inverted vertical visible menu',
      style = 'width: 15%; overflow-x: hidden;
               box-shadow: -2px 1px 16px 20px rgba(0,0,0,.1);',
      img(class = 'ui center aligned image', src = 'sralabLogo.png',
          style = 'height: auto; width: 100%'
      ),
      div(class = 'ui horizontal divider header',
          style = 'margin-top: 0px; margin-bottom: 0.5em',
          HTML('<i class = "fa fa-area-chart fa-2x"></i>')
      ),
      introBox(
        div(class = 'content', uiOutput('patStats')),
        data.step = 10,
        data.intro = 'Finally, this is the sidebar. Under the AbilityLab logo,
                      percentage increases/decreases in AQ scores will be
                      displayed. Note that 1): Percentages are computed
                      relative to the minimum/maximum of each listed score and
                      2): Each reported score has a different minimum an
                      maximum'
      ),
      div(class = 'ui horizontal divider header',
          style = 'margin-top: 2px; margin-bottom: 2px;',
          HTML('<i class = "fa fa-id-card fa-2x"></i>')
      ),
      div(class = 'content', uiOutput('patStats2'))
  )
}
  
## Styling and layout for the "sticky" rail on the right-hand side of the
## dashboard. It is comprised of two elements: 1) the "remote control" at the
## top of the rail that is associated with a collection of event handlers that
## can do things like change the domain, produce reports, and navigate, and 2)
## the "Update FIM" element that allows users to correct aberrant FIM data.
railOpts <- function(){
  div(class = 'ui centered right rail', style = 'width: 20%;',
      div(class = 'ui fixed top sticky', style = 'width: 90%;',
          introBox(
            div(class = 'card shadowed',
                style = 'height: auto; width: 15%; margin-top: 5em;
                         border-radius: .28571429rem;',
                div(class = 'content',
                    style = 'text-align: center; background-color: #1b1c1d;
                             border-top-left-radius: .28571429rem;
                             border-top-right-radius: .28571429rem;
                             padding-top: 4px; padding-bottom: 3px;',
                    HTML('<span style = "font-size: 1.5em;"
                                class = "bold white"
                          >
                            Domain
                          </span>'
                    )
                ),
                introBox(
                  div(class = 'content',
                      div(class = 'ui three item menu', id = 'domainselect',
                          style = 'background-color: #f36b21;
                                   border-radius: 0; border: 0;
                                   border-color: #f36b21;
                                   border-left: 1px solid #f36b21;
                                   border-right: 1px solid #f36b21;',
                          tags$a(title = 'Self Care', id = 'scButton',
                                 class = 'item selectedsection
                                          faa-parent animated-hover',
                                 style = 'border: 0; border-radius: 0;',
                                 icon('bath', lib = 'font-awesome',
                                      class = 'fa-2x faa-shake white'
                                 )
                          ),
                          tags$a(title = 'Mobility', id = 'mobButton',
                                 class = 'item notselectedsection
                                          faa-parent animated-hover',
                                 style = 'border: 0; border-radius: 0;',
                                 icon('walking', lib = 'font-awesome',
                                      class = 'fa fa-2x faa-shake white'
                                 )
                          ),
                          tags$a(title = 'Cognition', id = 'cogButton',
                                 class = 'item notselectedsection
                                          faa-parent animated-hover',
                                 style = 'border: 0; border-radius: 0;',
                                 icon('brain', lib = 'font-awesome',
                                      class = 'fa-2x faa-shake white'
                                 )
                          )
                      )
                  ),
                  data.step = 2,
                  data.intro = 'These buttons change the domain between
                                Self-Care, Mobility, and Cognition.'
                ),
                div(class = 'content',
                    style = 'text-align: center; background-color: #1b1c1d;
                             padding-top: 5px; padding-bottom: 5px;',
                    HTML('<span style = "font-size: 1.5em"
                                class = "bold white"
                          >
                            Jump To
                          </span>'
                    )
                ),
                introBox(
                  div(class = 'content',
                      div(class = 'ui four item menu',
                          style = 'background-color: #ed1c2c; border: 0;
                                   border-radius: 0;
                                   border-left: 1px solid #ed1c2c;
                                   border-right: 1px solid #ed1c2c;',
                          tags$a(title = 'Patient Select',
                                 class = 'item
                                          faa-parent animated-hover',
                                 style = 'border: 0; border-radius: 0;',
                                 href = '#patSelect',
                                 icon('th-list', lib = 'font-awesome',
                                      class = 'fa-2x faa-shake white'
                                 ),
                                 id = 'sapButton'
                          ),
                          tags$a(title = 'Goal Tracker',
                                 class = 'item
                                          faa-parent animated-hover',
                                 style = 'border: 0; border-radius: 0;',
                                 href = '#goalCard',
                                 icon('bar-chart', lib = 'font-awesome',
                                      class = 'fa-2x faa-shake white'
                                 ),
                                 id = 'gtButton'
                          ),
                          tags$a(title = 'AQ Scores and Typical Recovery',
                                 style = 'border: 0; border-radius: 0;',
                                 class = 'item
                                          faa-parent animated-hover',
                                 href = '#progCard',
                                 icon('line-chart', lib = 'font-awesome',
                                      class = 'fa-2x faa-shake white'
                                 ),
                                 id = 'trcButton'
                          ),
                          tags$a(title = 'Timeline',
                                 class = 'item
                                          faa-parent animated-hover',
                                 style = 'border: 0; border-radius: 0;',
                                 href = '#patTimeline',
                                 icon('calendar-alt', lib = 'font-awesome',
                                      class = 'fa-2x faa-shake white'
                                 ),
                                 id = 'tlButton'
                          )
                      )
                  ),
                  data.step = 3,
                  data.intro = 'These buttons will jump between the different
                                dashboard sections. It\'s easier than
                                scrolling!'
                ),
                div(class = 'content',
                    style = 'max-height: 50px; text-align: center;
                             background-color: #1b1c1d; padding-top: 5px;
                             padding-bottom: 5px;',
                    HTML('<span style = "font-size: 1.5em"
                                class = "bold white"
                          >
                            Download Report
                          </span>'
                    )
                ),
                introBox(
                  div(class = 'content',
                      div(class = 'ui two item menu',
                          style = 'background-color: #ffd100; border: 0;
                                   border-radius: 0;
                                   border-left: 1px solid #ffd100;
                                   border-right: 1px solid #ffd100;',
                          downloadLink('report1',
                                       style = 'border-color: #ffd100;
                                                border: 0;
                                                border-radius: 0;',
                                       icon('file-code-o',
                                            class = 'fa-2x faa-shake'
                                       ),
                                       class = 'item white
                                                faa-parent animated-hover',
                                       title = 'Download as HTML'
                          ),
                          downloadLink('report2',
                                       style = 'border-color: #ffd100;
                                                border: 0;
                                                border-radius: 0;',
                                       icon('file-image-o',
                                            class = 'fa-2x faa-shake'
                                       ),
                                       class = 'item white
                                                faa-parent animated-hover',
                                       title = 'Download as PNG'
                          )
                      )
                  ),
                  data.step = 4,
                  data.intro = 'These buttons allow you to make distributable
                                AQ Dashboard reports. Note that you\'ll have to
                                make one for each domain. You can download the
                                report either as a self-contained interactive
                                webpage (best for emailing) or as an image
                                (best for printing).'
                ),
                div(class = 'content',
                    style = 'max-height: 50px; text-align: center;
                             background-color: #1b1c1d; padding-top: 5px;
                             padding-bottom: 5px;',
                    HTML('<span style = "font-size: 1.5em"
                                class = "bold white"
                          >
                            Help
                          </span>'
                    )
                ),
                introBox(
                  div(class = 'content',
                      div(class = 'ui one item menu',
                          style = 'background-color: #6d2077;
                                   border: 0;
                                   border-bottom-left-radius: .28571429rem;
                                   border-bottom-right-radius: .28571429rem;
                                   border-top-left-radius: 0rem;
                                   border-top-right-radius: 0rem;
                                   border-left: 1px solid #6d2077;
                                   border-right: 1px solid #6d2077;
                                   border-bottom: 1px solid #6d2077;',
                        tags$a(title = 'Help',
                               class = 'item
                                        faa-parent animated-hover',
                               id = 'help',
                               icon('question-circle', lib = 'font-awesome',
                                    class = 'fa-2x faa-shake white'
                               )
                        )
                    )
                  ),
                  data.step = 5,
                  data.intro = 'This is the help button, which you have clearly
                                already figured out.'
                )
            ),
            data.step = 1,
            data.intro = 'This is the remote control. It will help you navigate
                          and modify the dashboard.'
          )
      ),
      div(class = 'ui fixed bottom sticky', style = 'width: 90%;',
          div(class = 'card shadowed',
              style = 'height: auto; width: 15%; margin-bottom: 5em;
                       border-radius: .28571429rem;',
              div(class = 'content',
                  style = 'text-align: center; background-color: #1b1c1d;
                           border-top-left-radius: .28571429rem;
                           border-top-right-radius: .28571429rem;
                           padding-top: 5px; padding-bottom: 5px;',
                  HTML('<span style = "font-size: 1.5em;"
                              class = "bold white"
                        >
                          Update FIM
                        </span>'
                  )
              ),
              div(class = 'content',
                  div(class = 'ui styled accordion',
                      style = 'border-radius: 0rem;',
                      div(class = 'ui title',
                          HTML('<i class = "dropdown icon" id = "scEditIcon">
                                </i>'
                          ),
                          HTML('<span id = "scEditTitle">Self-Care</span>')
                      ),
                      div(class = 'ui content',
                          uiOutput('scEdit')
                      ),
                      div(class = 'ui title',
                          HTML('<i class = "dropdown icon" id = "mobEditIcon">
                                </i>'
                          ),
                          HTML('<span id = "mobEditTitle">Mobility</span>')
                      ),
                      div(class = 'ui content',
                          uiOutput('mobEdit')
                      ),
                      div(class = 'ui title',
                          HTML('<i class = "dropdown icon" id = "cogEditIcon">
                                </i>'
                          ),
                          HTML('<span id = "cogEditTitle">Cognition</span>')
                      ),
                      div(class = 'ui content',
                          uiOutput('cogEdit')
                      )
                  )
              ),
              div(id = 'fimButton',
                  class = 'ui orange button',
                  style = 'width: 100%; border-top-right-radius: 0rem;
                           border-top-left-radius: 0rem;',
                  HTML('<i class = "redo alternate"></i>
                        <span style = "color: white">Refresh FIM</span>'
                  )
              )
          )
      )
  )
}

## Styling and layout for the "Select a Patient" view of the dashboard. The
## content of this element is governed by the patients that the SQL queries
## of the EDW find, and the interactive datatable is rendered at the bottom
## of the data operations chunk in server.R.
patients <- function(){
  div(class = 'ui centered cards', style = 'margin: auto',
      div(class = 'ui card shadowed',
          style = 'width: 100%; height: auto;  border-radius: .28571429rem;',
          id = 'patCard',
          div(class = 'content', style = 'background-color: #1b1c1d;'),
          div(class = 'content',
              div(class = 'ui large orange ribbon label shadowed',
                  style = 'font-size: 20px; margin-bottom: 15px;',
                  HTML('<span style="width: 100%; padding-left: 10px;">
                          <i class="fa fa-th-list" style="float:left;"></i>
                          Select a Patient
                        </span>'
                  )
              ),
              introBox(
                div(id = 'dtWrapper', #class = 'shadowed',
                    style = 'padding: 0; margin: 0;
                             border-radius: .28571429rem;
                             font-size: 18px;',
                    withLoader(
                      DT::dataTableOutput('patientDT', width = 'auto'),
                      type = 'html',
                      loader = 'www/sralabPreloader'
                    )
                ),
                data.step = 6,
                data.intro = 'This is the table where you select patients.
                              Clicking on a patient name will display their
                              AQ information. Use the search bar to look up
                              specific patients, diagnoses, or floors. The
                              numbered buttons on the bottom of the table
                              will jump between pages. You can also sort the
                              table by any column by clicking the orange
                              up/down arrows next to the column header.'
              )
          ),
          div(class = 'content',
              style = 'max-height: 50px; text-align: center;
                       background-color: #1b1c1d;'
          )
      )
  )
}

## Styling and layout for the "FIM Goals" part of the dashboard. Content for
## the barcharts displayed therein is generated by the goalPlotSC, goalPlotMob,
## and goalPlotCog functions, though there are a smattering of helper functions
## and event handlers (especially the updateFIM set of functions) that control
## updates to the chart.
goals <- function(){
  div(
    div(class = 'ui centered cards', style = 'margin: auto',
      div(class = 'card shadowed', style = 'width: 100%; height: auto;',
          id = 'goalCard',
          div(class = 'content',
              style = 'height: 42px; max-height: 42px;
                       background-color: #1b1c1d;',
              tags$a(id = 'btnFullscreen3', class = 'item',
                     icon('expand-arrows-alt', lib = 'font-awesome',
                          class = "right floated white"
                     ),
                     style = 'border-color: #000000;')
          ),
          div(class = 'content',
              div(class = 'ui large orange ribbon label shadowed',
                  style = 'font-size: 20px; margin-bottom: 5px;',
                  HTML('<span style="width: 100%; padding-left: 10px;">
                          <i class="fa fa-bar-chart" style="float:left;"></i>
                          Goal Tracker
                        </span>'
                  )
              ),
              div(style = 'height: 1em; width: 100%'),
              introBox(
                div(class = 'ui one column centered grid',
                    uiOutput('patGoals', class = 'width100')
                ),
                data.step = 7,
                data.intro = 'This section reports FIM goals, actual FIM
                              functional levels, and the FIM values typical for
                              patients with the same AQ score as the selected
                              patient.'
              )
          ),
          div(class = 'content',
              style = 'height: 29px; max-height: 29px; text-align: center;
                       background-color: #1b1c1d;'
          )
      )
    )
  )
}

## Styling and layout for the "Typical Recovery Curves." Although the primary
## functions rendering content in this view are linePlotSC, linePlotMob,
## linePlotCog, initTC_sc, initTC_mob, and initTC_cog, I would wager that
## roughly half of the server.R file contributes solely to this view.
regTC <- function(){
  div(class = 'ui centered cards', style = 'margin: auto',
    div(class = 'card shadowed', style = 'width: 100%; height: auto;',
        id = 'progCard',
        div(class = 'content',
            style = 'background-color: #1b1c1d; height: 42px;
                     max-height: 42px;',
            tags$a(id = 'btnFullscreen2', class = 'item',
                   icon('expand-arrows-alt', lib = 'font-awesome',
                        class = "right floated white"
                   ),
                   style = 'border-color: #000000;'
            )
        ),
        div(class = 'content',
            div(class = 'ui large orange ribbon label shadowed',
                style = 'font-size: 20px; margin-bottom: 5px;',
                HTML('<span style="width: 100%; padding-left: 10px;">
                        <i class="fa fa-line-chart" style="float:left;"></i>
                        AQ Scores and Typical Recovery
                      </span>'
                )
            ),
            introBox(
              div(class = 'content', uiOutput('patProg')),
              data.step = 8,
              data.intro = 'This chart shows the patient\'s progress over
                            time. The orange line always represents the AQ
                            score of the selected domain. Domain subscores
                            can be added (if available) by clicking their
                            names in the legend at the top of the chart.
                            Additionally, you can fullscreen the chart by
                            clicking on the four-headed arrow icon to the top
                            right of the chart.'
            )
        ),
        div(class = 'content',
            style = 'height: 29px; max-height: 29px; text-align: center;
                     background-color: #1b1c1d'
        )
    )
  )
}

## Styling and layout for the "FIM Timeline" view. The timevis element in this
## section is initially generated by improvementTL and updated using renderTL.
impTL <- function(){
  div(class = 'ui centered cards', style = 'margin: auto',
      div(class = 'card shadowed', style = 'width: 100%; height: auto;',
          id = 'tlCard',
          div(class = 'content',
              style = 'height: 42px; max-height: 42px;
                       background-color: #1b1c1d;',
              tags$a(id = 'btnFullscreen4',
                     class = 'item',
                     icon('expand-arrows-alt', lib = 'font-awesome',
                          class = 'right floated white'
                     ),
                     style = 'border-color: #000000;'
              )
          ),
          div(class = 'content',
              div(class = 'ui large orange ribbon label shadowed',
                  style = 'font-size: 20px; margin-bottom: 15px;',
                  HTML('<span style="width: 100%; padding-left: 10px;">
                          <i class="fa fa-calendar-alt" style="float:left"></i>
                          FIM Improvement Timeline
                        </span>'
                  )
              ),
              introBox(
                div(class = 'content',
                    uiOutput('patTL', class = 'width100')
                ),
                data.step = 9,
                data.intro = 'This is the FIM Improvement Timeline. If a
                              patient is very close to their typical recovery
                              curve, this view can be helpful in predicting
                              when further FIM gains will occur.'
              )
          ),
          div(class = 'content',
              style = 'height: 29px; max-height: 29px; text-align: center;
                       background-color: #1b1c1d'
          )
      )
  )
}

} # div setup for report/control sections

## With all of the necessary functions defined, this part actually lays them
## out as a webpage. Note that this uses Semantic UI instead of Bootstrap.
## Though Bootstrap is the default for shiny, I find it to be a bit too
## restrictive and somewhat poor at interactivity. Additionally, Semantic UI is
## much easier to write (for example, centering elements vertically when a
## parent element's height isn't defined is no longer an absolute chore). It
## also contains nice-looking and useful elements like cards, accordions, and
## grids that are easy to set up.
ui <- semanticPage(title = 'AQ Dashboard',
  ## The page head. I use a slightly more up-to-date versrion of jquery, which
  ## I invoke here. I also use a little jQuery script to prevent the different
  ## versions from conflicting with each other's methods.
  tags$head(
    HTML('<script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>'),
    HTML('<link rel="stylesheet"
                href="https://use.fontawesome.com/releases/v5.4.2/css/all.css"
                integrity="sha384-/rXc/GQVaYpyDdyxK+ecHPVYJSN9bmVFBvjA/9eOB+pb3F2w2N6fc5qB9Ew5yIns"
                crossorigin="anonymous"
          >'
    ),
    tags$script("$.noConflict(true);"),
    includeCSS('www/aqDash.css'),
    HTML('<link rel="stylesheet" href="font-awesome-animation.min.css">'),
    tags$link(rel = 'shortcut icon', href = 'favicon.png')
  ),
  ## The header, where I put the CSS from above.
  ## Activates shinyjs
  useShinyjs(),
  ## Activates introjs
  introjsUI(),
  ## Suppresses Bootstrap, which sometimes interferes with Semantic UI
  suppressDependencies('bootstrap'),
  div(style = 'width: 100%; position: relative;',
      ## The sidebar is rendered first.
      sidebar(),
      ## Then we get the real "meat and potatoes," which are the segments
      ## in the middle of the page.
      div(class = 'ui segments',
          style = 'padding-left: 17.5%; padding-right: 2.5%; width: 85%;
                   border: 0px; box-shadow: none; margin-bottom: 5em;',
          id = 'page',
          ## Although this seems a weird place to put it, the rail actually
          ## needs to be a child element of the element it's attached to.
          ## Because I wanted it to always follow the main page content and
          ## have the same margins, the rail is placed here.
          railOpts(),
          div(id = 'sortPlots',
              style = 'border-radius: .28571429rem; position: relative;',
              class = 'shadowed',
              ## "Select a Patient"
              div(class = 'ui orange segment', id = 'patSelect',
                  style = 'background-color: #b2b4b2; margin: 0;
                           border-bottom-left-radius: 0;
                           border-bottom-right-radius: 0;',
                  div(class = 'content',
                      patients()
                  )
              ),
              ## "FIM Goals"
              div(class = 'ui red segment',
                  style = 'background-color: #b2b4b2; margin: 0;
                           border-radius: 0;',
                  id = 'patGoal',
                  div(class = 'content',
                      goals()
                  )
              ),
              ## "Typical Recovery Curve"
              div(class = 'ui yellow segment',
                  style = 'background-color: #b2b4b2; margin: 0;
                           border-radius: 0;',
                  id = 'patProgress',
                  div(class = 'content',
                      regTC()
                  )
              ),
              ## "Timeline"
              div(class = 'ui purple segment', id = 'patTimeline',
                  style = 'background-color: #b2b4b2; margin: 0;
                           border-top-right-radius: 0;
                           border-top-left-radius: 0;',
                  div(class = 'content',
                      impTL()
                  )
              )
          )
      )
    ),
    div(style = 'font-size: 14px; position: relative; width: 100%;',
        HTML(
          '<span style = "color: #1b1c1d; position: absolute;
                          bottom: 5px; right: 45%;"
           >
             Powered by
             <a href = "https://cran.r-project.org/">
               <i class = "fab fa-r-project"
                  style = "color: #2567BB; font-size: 18px;">
               </i>
             </a>
             <a href = "https://www.javascript.com/">
               <i class = "fab fa-js-square fa-stack-1x"
                  style = "color: #F1DA4E; font-size: 18px;
                           left: 6em; top: -.05em;
                           width: 1em;">
               </i>
               <i class = "fa fa-square"
                  style = "color: #000000; font-size 18px;
                           left: .75em">
               </i>

             </a>
             <a href = "https://www.w3.org/TR/html5/">
               <i class = "fab fa-html5"
                  style = "color: #EA642A; font-size: 18px;">
               </i>
             </a>
             <a href = "https://www.w3.org/TR/CSS/">
               <i class = "fab fa-css3-alt"
                  style = "color: #284DE4; font-size: 18px;">
               </i>
             </a>
             <a href = "https://aws.amazon.com/">
               <i class = "fab fa-aws"
                  style = "color: #24303E; font-size: 18px;">
               </i>
             </a>
             <a href = "https://en.wikipedia.org/wiki/Coffee">
               <i class = "fas fa-coffee"
                  style = "color: #441B0A; font-size: 18px;">
               </i>
             </a>
          </span>'
        )
    )
)
