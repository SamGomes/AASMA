;;;
;;;  Global variables and constants
extensions [array]
;;;
;;; NUM-ACTIONS: number of actions considered
;;; epsilon: decay probability of learning reward value decreases over time.
;;; temperature: parameter influencing action selection in soft-max
;;; time-steps: number of time-steps in the current episode.
;;; episode-count: total number of episodes

globals [NUM-ACTIONS ACTION-LIST epsilon temperature time-steps episode-count total-time-steps]


;;;
;;;  Declare two types of turtles
;;;

breed [wolves wolf]
breed [preys prey]

;;;
;;;
;;;Wolves internal states:
;;;
;;;fov: field of view
;;;wolves_plan: each wolf has a list of his and the other wolves path plan:
;;; possible plans are 0 - approach left
;;; 1- approach right
;;; 2- approach from above
;;; 3- approach from down
;;;
;;; Q-values: Q-value function updated by Q-learning in the form (x y action) -> value
;;; reward: current reward number
;;; total-reward: cumulative reward so far
;;; init_xcor: initial xcor for reset
;;; init_ycor
wolves-own[fov wolves_plan Q-values reward total-reward init_xcor init_ycor previous-xcor previous-ycor]
;;;
;;;

;;;  =================================================================
;;;      Interface reports
;;;  =================================================================
to-report get-total-time-steps
  report total-time-steps
end

to-report get-episode-count
  report episode-count
end
;;;  =================================================================
;;;      Setup
;;;  =================================================================
to setup
  clear-all
  set-globals
  setup-patches
  setup-turtles
  reset-ticks
end

to set-globals
  set time-steps 0
  set epsilon 1
  set temperature 100

  set ACTION-LIST (list
    list 0 1 ; go up (north)
    list 0 -1 ; go down (south)
    list 1 0 ; move ahead
    list -1 0 ; move back
    )
  set NUM-ACTIONS 4
end

;;;  Setup patches.
;;;
to setup-patches
  resize-world 0 world_size 0 world_size
  ask patches [ set pcolor white ]
  ask patches with [ (pxcor + pycor) mod 2 = 0 ][ set pcolor gray + 4.5 ]
end


to setup-turtles
    set-default-shape  wolves "turtle"
    set-default-shape preys  "cow"


create-wolves 4[
  set color blue
  set label who
  set fov floor (world_size * (fov_percentage / 100))
  set wolves_plan [-1 -1 -1 -1]
  set label-color black
  set size .9
  set-random-position
  set init_xcor xcor
  set init_ycor ycor
  set previous-xcor (xcor + max-pxcor)
  set previous-ycor (ycor + max-pycor)
  set Q-values get-initial-Q-values
  set reward 0
  set total-reward 0
]
; change colors of 2 3 and 4

ask turtle 1 [set color orange]
ask turtle 2 [set color magenta]
ask turtle 3 [set color green]

create-preys 1[
  set color pink
  set label who
  set label-color black
  set size .9
  set heading 0
  set-random-position
]
end



to set-random-position
  setxy random-pxcor random-pycor
  while [any? other turtles-here] [
    setxy random-pxcor random-pycor
  ]
end

to reset
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  ;;__clear-all-and-reset-ticks
  ask wolves[
    set-current-plot "Reward performance"
    set-current-plot-pen (word who "reward")
      plot total-reward
      set total-reward 0

      ;resetar posições
      set xcor init_xcor
      set ycor init_ycor
      set previous-xcor xcor
      set previous-ycor ycor
    ]

      set-current-plot "Time perfomance"
      set-current-plot-pen "time-steps"
      plot time-steps
      set episode-count (episode-count + 1)
      set time-steps 0

      set epsilon max list 0 (1 - (episode-count / max-episodes))
      set temperature max list 0.8 (epsilon * 10)


end

to go
  tick

ifelse episode-finished? [
    reset
    if episode-count >= max-episodes [stop]
]
  [
    ask preys[
    prey-loop
  ]
  ask wolves[
    wolf-loop
  ]
  ]

end

to wolf-loop

    ifelse(gang_movement = "REACTIVE")
    [
      reactive-loop
    ]
    [
    ifelse(gang_movement = "DELIBERATIVE")
    [
      deliberative-loop
    ]
    [
      ifelse( gang_movement = "LEARNING")
      [
         wolf-learning-loop
    set total-time-steps (total-time-steps + 1)
    ]
      [
    ]
    ]
    ]

end


;;;
;;;  =================================================================
;;;
;;;      AGENT DEFINITION
;;;
;;;  =================================================================
;;;




;;;------------------------------------------------------------------------------------------------------------------------------------------------------------
;;;------------------------------------------------------------------------------------------------------------------------------------------------------------





to-report adjacents [node mobjectivo]
  let aux 0
  let aux2 0

  set aux2 []
  set aux adjacent-positions-of-type (last first node)

  foreach aux
  [
     set aux2 fput (list 0 ((item 1 first node) + 1) ?) aux2
  ]


  set aux []
  foreach aux2
  [
    set aux fput (list (replace-item 0 ? (heuristic ? mobjectivo)) first node) aux
  ]

  report aux
end



;;;
;;;  Add the distance to the goal position and the current node cost
;;;
to-report heuristic [node mgoal]
  let cost 0
  let x 0
  let y 0

  set cost item 1 node
  set x first item 2 node
  set y first butfirst item 2 node

  report cost +
         2 * (abs(x - item 0 mgoal) +  abs(y - item 1 mgoal))
end



to-report adjacent-positions-of-type [pos ]
  let solution 0
  let x item 0 pos
  let y item 1 pos

  set solution []

  set solution fput (list x ((y - 1) mod (world_size + 1))) solution

  set solution fput (list x ((y + 1) mod (world_size + 1))) solution

  set solution fput (list ((x - 1) mod (world_size + 1)) y) solution

  set solution fput (list ((x + 1) mod (world_size + 1)) y) solution

  report solution
end



to-report find-solution [node closed]
  let solution 0
  let parent 0


  set solution (list last first node)
  set parent item 1 node
  while [not empty? parent] [
    set parent first filter [ parent = first ? ] closed
    set solution fput last first parent solution
    set parent last parent
  ]


  report butfirst solution
end


;;;-------search algoritm (A star)--------------

to-report find-path [intialPos FinalPos]
  let opened 0
  let closed 0
  let aux 0
  let aux2 0
  let aux3 0
  let to-explore 0

  set to-explore []
  set closed []
  set opened []
  set opened fput (list (list 0 0 intialPos) []) opened


  while [not empty? opened]
  [

    set to-explore first opened
    set opened remove to-explore opened
    set closed fput to-explore closed


    ifelse last first to-explore = FinalPos
    [

        let solution find-solution to-explore closed
        foreach solution
        [
          if(not(legal-move? (first ?) (last ?) ))
          [
            set solution remove ? solution
          ]
        ]
      report solution
    ]
    [

      set aux adjacents to-explore FinalPos
      foreach aux
      [
        set aux2 ?
        set aux3 filter [ last first aux2 = last first ? and first first aux2 < first first ? ] opened
        ifelse not empty? aux3
        [
          set opened remove first aux3 opened
          set opened fput aux2 opened
        ]
        [
          set aux3 filter [ last first aux2 = last first ? ] closed
          ifelse not empty? aux3
          [
            if first first first aux3 > first first aux2
              [
                set closed remove first aux3 closed
                set opened fput aux2 opened
              ]
          ]
          [
            set opened fput aux2 opened
          ]
        ]
      ]

      ;; orders the opened list according to the heuristic
      set opened sort-by [ first first ?1 < first first ?2 ] opened
    ]
  ]
  report []
end


to seek [ point ]

  let nextDirX ((first point) - xcor)
  let nextDirY ((last point) - ycor)

  if(nextDirX > 0)[
    move-ahead
  ]
  if(nextDirX < 0)[
    move-back
  ]
  if(nextDirY > 0)[
    move-up
  ]
  if(nextDirY < 0)[
    move-down
  ]

end


to flee [ point ]

  let nextDirX ((first point) - xcor)
  let nextDirY ((last point) - ycor)

  if(nextDirX > 0)[
    move-back
  ]
  if(nextDirX < 0)[
    move-ahead
  ]
  if(nextDirY > 0)[
    move-down
  ]
  if(nextDirY < 0)[
    move-up
  ]

end

to-report zigZagWander[ point ]
  let nextPoint point
  let aux 0

  let range round (2 * fov + 1)

  if(range <= 3 )
  [
     set range 4
  ]

  if(((last point) mod range) > (range / 2))[

    ifelse((first point) = world_size)
    [
      set nextPoint (list (first point - 1) ((last point) + 1))
    ]
    [
      set nextPoint (list ((first point) + 1) (last point))
    ]
  ]
  if(((last point) mod range) <= (range / 2))[
    ifelse((first point) = world_size)
    [
      set nextPoint (list (first point + 1) ((last point) + 1))
    ]
    [
      set nextPoint (list ((first point) - 1) (last point))
    ]
  ]

  report nextPoint

end
;;;------------------------------------------------------------------------------------------------------------------------------------------------------------
;;;------------------------------------------------------------------------------------------------------------------------------------------------------------




;;;
;;; ------------------------
;;;   Loops
;;; ------------------------
;;;

to wolf-learning-loop
  let action select-action xcor ycor

  ;executes action
  execute-action action

  ; gets reward
  set reward get-reward action
  set total-reward (total-reward + reward)

  ;updates Q-value function Q-value function

  update-Q-value action
end


 to deliberative-loop

   let preyX 0
   let preyY 0

   ask preys [
    set preyX posX
    set preyY posY
   ]

   let solution find-path (list xcor ycor) ( list preyX preyY )

   ;seek  zigZagWander (list xcor ycor)
   seek  (list preyX preyY) ; so pros lols ;)

 end

 to reactive-loop
   ifelse  in-sight[
     let preyX 0
     let preyY 0
     let corner 0

     ask preys [
      set preyX posX
      set preyY posY
      ifelse in-corner
      [ set corner 1]
      [set corner 0]

     ]
     ifelse corner = 1
     [
       ifelse preyX < xcor[
          move-ahead
     ]
      [
        ifelse preyY < ycor[
        move-up
        ]
        [
          ifelse preyX > xcor[
            move-back
          ]
          [
            move-down
          ]
          ]
        ]
      ]

     [
       ifelse preyX > xcor[
          move-ahead
     ]
      [
        ifelse preyY > ycor[
        move-up
        ]
        [
          ifelse preyX < xcor[
            move-back
          ]
          [
            move-down
          ]
          ]
        ]
     ]
   ]
   [
     let i random 4
     if i = 0 [
    move-up
              ]
  if i = 1[
    move-down
        ]
  if i = 2[
    move-ahead
       ]
  if i = 3[
    move-back
      ]
   ]

 end




to prey-loop
  ifelse(prey_movement = "RANDOM")
  [
    random-loop
  ]
  [
  ifelse(prey_movement = "REACTIVE")
  [
    reactive-loop
  ]
  [
   ifelse(prey_movement = "FLEE")
  [
    flee-loop
  ]
  [
   ifelse(prey_movement = "NAIVE")
  [
    naive-loop
  ]
  [
  ]]]]
end




to naive-loop
  seek list (world_size / 2) (world_size / 2)
end


to flee-loop
  let averageX 0
  let averageY 0
  let counter 0;
  ask wolves
  [
    set averageX (averageX + posX)
    set averageY (averageY + posY)
    set counter (counter + 1)
  ]
  set averageX (averageX / counter)
  set averageY (averageY / counter)

  let distanceX (averageX)
  let distanceY (averageY)

  flee list distanceX distanceY

end

to random-loop
  let i random 5
  if i = 0 [
    move-up
  ]
  if i = 1[
    move-down
  ]
  if i = 2[
    move-ahead
  ]
  if i = 3[
    move-back
  ]
end



;;;
;;; ------------------------
;;;   Sensors
;;; ------------------------
;;;
to-report in-sight
    let preyX 0
     let preyY 0
     ask preys [
       set preyX posx
       set preyY posY
     ]
  report abs sqrt ( (preyX - xcor)*(preyX - xcor) + (preyY - ycor) * (preyY - ycor)) < fov
end

to-report in-corner
  let preyX 0
     let preyY 0
     ask preys [
       set preyX posx
       set preyY posY
     ]
  report (((preyX = 0) and ( preyY = 0)) or
         ((preyX = 0) and ( preyY = world_size)) or
         ((preyX = world_size) and (preyY = 0)) or
         ((preyX = world_size) and (preyY = world_size)))
end

to-report choose-dir
     let preyX 0
     let preyY 0
     let left-distance 0
     let right-distance 0
     let up-distance 0
     let down-distance 0
     let minim 0
     let lista-de-dist [ ]
     let indexList [ ]
     let plan -1
     ask preys [
       set preyX posx
       set preyY posY
     ]

  set left-distance distance-to-pos (preyX - 1) preyY
  set right-distance distance-to-pos (preyX + 1) preyY
  set up-distance distance-to-pos preyX (preyY + 1)
  set down-distance distance-to-pos preyX (preyY - 1)
  set lista-de-dist (list left-distance right-distance up-distance down-distance)
  set indexList n-values 4 [?]
  set indexList sort-by [ (item ?1 lista-de-dist ) < (item ?2 lista-de-dist)] indexList


  while [not empty? indexList] [
  let usedPlan? empty? filter [ ? = first indexList] wolves_plan
  ifelse usedPlan?
       [
         report first indexList]
       [ set indexList remove first indexList indexList]
  ]
report -1
end


;;;
;;; ------------------------
;;;   Actuators
;;; ------------------------
;;;

to move-diag-tl
  if(gang_legal_movement = "DIAGONALS")
  [
    let next-x xcor + 1
    let next-y ycor + 1
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 45
  ]
end

to move-diag-tr
  if(gang_legal_movement = "DIAGONALS")
  [
    let next-x xcor + 1
    let next-y ycor - 1
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 125
  ]
end

to move-diag-bl
  if(gang_legal_movement = "DIAGONALS")
  [
    let next-x xcor - 1
    let next-y ycor + 1
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 170
  ]
end


to move-diag-br
  if(gang_legal_movement = "DIAGONALS")
  [
    let next-x xcor - 1
    let next-y ycor - 1
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 215
  ]
end


to move-ahead
  if(gang_legal_movement = "HORIZONTALS" or gang_legal_movement = "ORTHOGONAL")
  [
    let next-x xcor + 1
    let next-y ycor + 0
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 90
  ]
end

to move-back
  if(gang_legal_movement = "HORIZONTALS" or gang_legal_movement = "ORTHOGONAL")
  [
    let next-x xcor - 1
    let next-y ycor + 0
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 270
  ]
end

to move-up
  if(gang_legal_movement = "VERTICALS" or gang_legal_movement = "ORTHOGONAL")
  [
    let next-x xcor + 0
    let next-y ycor + 1
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 0
  ]
end

to move-down
  if(gang_legal_movement = "VERTICALS" or gang_legal_movement = "ORTHOGONAL")
  [
    let next-x xcor + 0
    let next-y ycor - 1
    if legal-move? next-x next-y[
      set xcor next-x
      set ycor next-y
    ]
    set heading 180
  ]
end


;;;
;;; ------------------------
;;;   Auxiliars
;;; ------------------------
;;;
to-report legal-move? [x y]
  report (
    (not any? wolves-on patch x y) and
    (not any? preys-on patch x y))
end



 to-report posX
   report xcor
 end

 to-report posy
   report ycor
 end

to-report in-range-pos [x y]
  report max ( list ((x  - xcor ) mod (world_size + 1))  (( y - ycor ) mod (world_size + 1))  ) < fov
end
to-report distance-to-pos [x y]
    report max ( list ((x  - xcor ) mod (world_size + 1))  (( y - ycor ) mod (world_size + 1))  )
end

to send-message-to-wolf [id-wolf msg myId]
  ask turtle id-wolf [receive-message msg myId]
end

to receive-message [ sender msg ]
  set wolves_plan replace-item sender wolves_plan msg
end


to pass-message [dir]
 let myId label
 let myX xcor
 let myY ycor
 ask wolves [
   if in-range-pos myX myY
       [ send-message-to-wolf label dir myId]
 ]
 end

to-report get-reward [action]
  let next-x xcor + first action
  let next-y ycor + last action
  let preyX 0
  let preyY 0
   ask preys[
     set preyX xcor
     set preyY ycor
   ]
   ifelse (next-x = preyX) and (next-y = preyY)
   [ report reward-value ]
   []
   end; did it hit a wolf




to-report episode-finished?
  let end? 1
  let right? 0
  let left? 0
  let up? 0
  let down? 0
  let preyX 0
  let preyY 0
  ask preys[
    set preyX xcor
    set preyY ycor
  ]

  ask wolves [
  if (xcor = preyX + 1) and (ycor = preyY)
      [ set right? 1]
  if (xcor = preyX - 1) and (ycor = preyY)
      [set left? 1]
  if ( xcor = preyX) and (ycor = preyY + 1)
      [ set up? 1]
  if (xcor = preyX) and (ycor = preyY - 1)
      [set down? 1]
  ]
  report (left? = 1) and (right? = 1) and (up? = 1) and (down? = 1)
end

 to-report get-max-Q-value[x y]
   report max array:to-list get-Q-values x y
 end

 to set-Q-value [x y action value]
   array:set (get-Q-values x y) (get-action-index action) value
 end

 to-report get-Q-values [x y]
   report array:item (array:item Q-values x) y
 end

 to-report get-Q-value [x y action]
   let action-values get-Q-values x y
   report array:item action-values (get-action-index action)
 end

 to-report get-action-index [action]
   report position action ACTION-LIST
 end

 to-report get-initial-Q-values
   report array:from-list n-values world-width[
     array:from-list n-values world-height[
       array:from-list n-values NUM-ACTIONS[0]]]
 end
;;;
;;; ------------------------
;;;   Learning
;;; ------------------------
;;;
to execute-action [action]
   ;save previous position
   set previous-xcor xcor
   set previous-ycor ycor

   ;saves new position if  action goes to a legal state

   let next-x xcor + first action
   let next-y ycor + last action

   if legal-move? next-x next-y
   [
     set xcor next-x
     set ycor next-y
   ]

   set time-steps (time-steps + 1)
 end


to-report select-action [x y]
  report select-action-soft-max x y

 end

to update-Q-value [action]
  update-Q-learning action
end

;;;
;;;  Chooses an action according to the soft-max method.
;;;
;;;

to-report select-action-soft-max [x y]

  ; gets action probs
  let action-values array:to-list (get-Q-values x y)
  let action-probs map [ ( exp (? / temperature)) ] action-values
  let sum-q sum action-probs
  set action-probs map [? / sum-q ] action-probs

  ;choses random action
  let dice random-float 1
  let prob-sum item 0 action-probs
  let action-index 0
  while [ prob-sum < dice]
  [
    set action-index ( action-index + 1)
    set prob-sum ( prob-sum + (item action-index action-probs))
  ]
  report item action-index ACTION-LIST
end

to update-Q-learning [action]
  ;get previous Q-value
  let previous-Q-value (get-Q-value previous-xcor previous-ycor action)

  ; get funny math expression
  let prediction-error (reward + ( discount-factor * get-max-Q-value xcor ycor) - previous-Q-value)

; get funny math part 2
  let new-Q-value (previous-Q-value + ( learning-rate * prediction-error))


 ;sets new Q-value
 set-Q-value previous-xcor previous-ycor action new-Q-value
end
@#$#@#$#@
GRAPHICS-WINDOW
248
26
573
372
-1
-1
15.0
1
10
1
1
1
0
1
1
1
0
20
0
20
0
0
1
ticks
30.0

BUTTON
12
27
77
60
NIL
Reset
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
148
27
211
60
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
81
27
144
60
step
tick
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
121
192
154
world_size
world_size
10
100
20
1
1
NIL
HORIZONTAL

SLIDER
19
173
191
206
fov_percentage
fov_percentage
0
50
50
1
1
NIL
HORIZONTAL

CHOOSER
20
311
191
356
prey_movement
prey_movement
"RANDOM" "REACTIVE" "FLEE" "NAIVE"
1

CHOOSER
24
532
195
577
gang_movement
gang_movement
"REACTIVE" "DELIBERATIVE" "LEARNING"
0

TEXTBOX
1
90
208
115
         World Parameters
15
0.0
1

CHOOSER
23
465
196
510
gang_legal_movement
gang_legal_movement
"DIAGONALS" "ORTHOGONAL" "HORIZONTALS" "VERTICALS"
1

TEXTBOX
51
277
201
296
Prey Parameters
15
0.0
1

TEXTBOX
38
427
188
446
Predators Parameters
15
0.0
1

TEXTBOX
354
421
504
440
Learning Parameters
15
0.0
1

SLIDER
232
455
404
488
discount-factor
discount-factor
0
1
0.13
0.01
1
NIL
HORIZONTAL

SLIDER
231
498
403
531
learning-rate
learning-rate
0
1
1
0.1
1
NIL
HORIZONTAL

SLIDER
231
542
403
575
reward-value
reward-value
0
5
5
0.2
1
NIL
HORIZONTAL

SLIDER
421
541
619
574
max-episodes
max-episodes
0
1000
50
50
1
NIL
HORIZONTAL

SLIDER
419
453
619
486
hit-wolf-reward
hit-wolf-reward
-1
0
0
0.01
1
NIL
HORIZONTAL

SLIDER
421
496
619
529
sheep-out-of-range-reward
sheep-out-of-range-reward
-1
0
0
0.01
1
NIL
HORIZONTAL

BUTTON
188
76
254
109
Setup
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
