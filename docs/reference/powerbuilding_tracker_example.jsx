import React, { useState, useEffect } from 'react';
import { Check, RotateCcw, Dumbbell, Trophy } from 'lucide-react';

const workoutData = [
  {
    day: "Day 1",
    title: "Squat & Lower Body",
    exercises: [
      {
        name: "Squat",
        sets: [
          { reps: "5", weight: "75kg" }, { reps: "5", weight: "75kg" },
          { reps: "5", weight: "75kg" }, { reps: "5", weight: "75kg" }
        ]
      },
      {
        name: "Pause Squats",
        sets: [
          { reps: "3", weight: "60kg" }, { reps: "3", weight: "60kg" }, { reps: "3", weight: "60kg" }
        ]
      },
      {
        name: "Leg Press",
        sets: [
          { reps: "12", weight: "—" }, { reps: "12", weight: "—" }, { reps: "12", weight: "—" }
        ]
      },
      {
        name: "Leg Extensions",
        sets: [
          { reps: "15", weight: "—" }, { reps: "15", weight: "—" }, { reps: "15", weight: "—" }
        ]
      },
      {
        name: "Calf Raises",
        sets: [
          { reps: "15-20", weight: "—" }, { reps: "15-20", weight: "—" },
          { reps: "15-20", weight: "—" }, { reps: "15-20", weight: "—" }
        ]
      }
    ]
  },
  {
    day: "Day 2",
    title: "Bench & Upper Body",
    exercises: [
      {
        name: "Bench Press",
        sets: [
          { reps: "5", weight: "75kg" }, { reps: "5", weight: "75kg" },
          { reps: "5", weight: "75kg" }, { reps: "5", weight: "75kg" }
        ]
      },
      {
        name: "Spoto Press",
        sets: [
          { reps: "4", weight: "65kg" }, { reps: "4", weight: "65kg" }, { reps: "4", weight: "65kg" }
        ]
      },
      {
        name: "Chest-Supported Rows",
        sets: [
          { reps: "10-12", weight: "—" }, { reps: "10-12", weight: "—" }, { reps: "10-12", weight: "—" }
        ]
      },
      {
        name: "Lat Pulldowns",
        sets: [
          { reps: "10-12", weight: "—" }, { reps: "10-12", weight: "—" }, { reps: "10-12", weight: "—" }
        ]
      },
      {
        name: "Triceps Rope Pushdowns",
        sets: [
          { reps: "12-15", weight: "—" }, { reps: "12-15", weight: "—" }, { reps: "12-15", weight: "—" }
        ]
      },
      {
        name: "Dumbbell Bicep Curls",
        sets: [
          { reps: "12-15", weight: "—" }, { reps: "12-15", weight: "—" }, { reps: "12-15", weight: "—" }
        ]
      }
    ]
  },
  {
    day: "Day 3",
    title: "Deadlift & Shoulders",
    exercises: [
      {
        name: "Conventional Deadlift",
        sets: [
          { reps: "5", weight: "80kg" }, { reps: "5", weight: "70kg" }, { reps: "5", weight: "70kg" }
        ]
      },
      {
        name: "Goblet Squats",
        sets: [
          { reps: "10", weight: "—" }, { reps: "10", weight: "—" }, { reps: "10", weight: "—" }
        ]
      },
      {
        name: "Hamstring Curls",
        sets: [
          { reps: "12", weight: "—" }, { reps: "12", weight: "—" }, { reps: "12", weight: "—" }
        ]
      },
      {
        name: "Seated DB Shoulder Press",
        sets: [
          { reps: "10-12", weight: "—" }, { reps: "10-12", weight: "—" }, { reps: "10-12", weight: "—" }
        ]
      },
      {
        name: "Cable Lateral Raises",
        sets: [
          { reps: "15", weight: "—" }, { reps: "15", weight: "—" }, { reps: "15", weight: "—" }
        ]
      }
    ]
  }
];

export default function App() {
  const [activeDay, setActiveDay] = useState(0);
  
  // Initialize state from localStorage or default to empty object
  const [completedSets, setCompletedSets] = useState(() => {
    try {
      const saved = localStorage.getItem('powerbuilding-tracker-state');
      return saved ? JSON.parse(saved) : {};
    } catch (e) {
      console.error("Failed to load state", e);
      return {};
    }
  });

  // Save to localStorage whenever completedSets changes
  useEffect(() => {
    localStorage.setItem('powerbuilding-tracker-state', JSON.stringify(completedSets));
  }, [completedSets]);

  const toggleSet = (dayIndex, exerciseIndex, setIndex) => {
    const key = `${dayIndex}-${exerciseIndex}-${setIndex}`;
    setCompletedSets(prev => ({
      ...prev,
      [key]: !prev[key]
    }));
  };

  const resetDay = () => {
    if (window.confirm("Are you sure you want to reset today's progress?")) {
      const newCompleted = { ...completedSets };
      Object.keys(newCompleted).forEach(key => {
        if (key.startsWith(`${activeDay}-`)) {
          delete newCompleted[key];
        }
      });
      setCompletedSets(newCompleted);
    }
  };

  const currentWorkout = workoutData[activeDay];
  
  // Calculate progress for the current day
  let totalSets = 0;
  let finishedSets = 0;
  
  currentWorkout.exercises.forEach((ex, exIdx) => {
    ex.sets.forEach((set, setIdx) => {
      totalSets++;
      if (completedSets[`${activeDay}-${exIdx}-${setIdx}`]) {
        finishedSets++;
      }
    });
  });

  const progressPercentage = totalSets === 0 ? 0 : Math.round((finishedSets / totalSets) * 100);
  const isDayComplete = progressPercentage === 100;

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 font-sans">
      {/* Header */}
      <header className="bg-slate-900 text-white p-4 shadow-md sticky top-0 z-10">
        <div className="max-w-md mx-auto flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Dumbbell className="w-6 h-6 text-emerald-400" />
            <h1 className="text-xl font-bold tracking-tight">Powerbuilder</h1>
          </div>
          <button 
            onClick={resetDay}
            className="p-2 text-slate-300 hover:text-white transition-colors flex items-center justify-center rounded-full hover:bg-slate-800 active:scale-95"
            title="Reset Day"
          >
            <RotateCcw className="w-5 h-5" />
          </button>
        </div>
      </header>

      <main className="max-w-md mx-auto p-4 pb-24">
        {/* Day Selector */}
        <div className="flex space-x-2 mb-6 bg-slate-200 p-1 rounded-xl">
          {workoutData.map((day, idx) => (
            <button
              key={idx}
              onClick={() => setActiveDay(idx)}
              className={`flex-1 py-2 px-3 rounded-lg text-sm font-semibold transition-all duration-200 ${
                activeDay === idx 
                  ? 'bg-white text-slate-900 shadow-sm' 
                  : 'text-slate-600 hover:bg-slate-300'
              }`}
            >
              {day.day}
            </button>
          ))}
        </div>

        {/* Workout Title & Progress */}
        <div className="mb-6">
          <h2 className="text-2xl font-black text-slate-900 mb-2">{currentWorkout.title}</h2>
          
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-slate-500">
              Progress: {finishedSets} / {totalSets} sets
            </span>
            <span className="text-sm font-bold text-emerald-600">{progressPercentage}%</span>
          </div>
          
          <div className="w-full bg-slate-200 h-2.5 rounded-full overflow-hidden">
            <div 
              className="bg-emerald-500 h-2.5 rounded-full transition-all duration-500 ease-out"
              style={{ width: `${progressPercentage}%` }}
            ></div>
          </div>
        </div>

        {/* Completion Message */}
        {isDayComplete && (
          <div className="bg-emerald-100 border border-emerald-200 text-emerald-800 p-4 rounded-xl mb-6 flex items-center gap-3 shadow-sm animate-in fade-in slide-in-from-top-4">
            <Trophy className="w-6 h-6 text-emerald-600" />
            <p className="font-semibold text-sm">Workout complete! Great job today.</p>
          </div>
        )}

        {/* Exercises List */}
        <div className="space-y-4">
          {currentWorkout.exercises.map((exercise, exIdx) => (
            <div key={exIdx} className="bg-white border border-slate-200 rounded-2xl p-5 shadow-sm">
              <h3 className="text-lg font-bold text-slate-800 mb-4">{exercise.name}</h3>
              
              <div className="flex flex-col gap-3">
                {exercise.sets.map((set, setIdx) => {
                  const isChecked = completedSets[`${activeDay}-${exIdx}-${setIdx}`] || false;
                  
                  return (
                    <button
                      key={setIdx}
                      onClick={() => toggleSet(activeDay, exIdx, setIdx)}
                      className={`relative flex items-center justify-between p-4 rounded-xl border-2 transition-all duration-200 active:scale-[0.98] ${
                        isChecked 
                          ? 'border-emerald-500 bg-emerald-50 text-emerald-900' 
                          : 'border-slate-100 bg-slate-50 text-slate-700 hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center gap-4">
                        {/* Checkbox circle */}
                        <div className={`w-8 h-8 rounded-full border-2 flex items-center justify-center transition-colors ${
                          isChecked 
                            ? 'bg-emerald-500 border-emerald-500 text-white' 
                            : 'border-slate-300 bg-white'
                        }`}>
                          {isChecked && <Check className="w-5 h-5" />}
                        </div>
                        
                        {/* Set info */}
                        <div className="flex flex-col items-start text-left">
                          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-0.5">
                            Set {setIdx + 1}
                          </span>
                          <span className={`font-bold ${isChecked ? 'text-emerald-800' : 'text-slate-800'}`}>
                            {set.reps} Reps
                          </span>
                        </div>
                      </div>

                      {/* Weight badge */}
                      {set.weight !== "—" && (
                        <div className={`px-3 py-1.5 rounded-lg text-sm font-bold ${
                          isChecked 
                            ? 'bg-emerald-200/50 text-emerald-800' 
                            : 'bg-slate-200 text-slate-700'
                        }`}>
                          {set.weight}
                        </div>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}