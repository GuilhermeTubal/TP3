import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;



Future<void> testNotification() async {
  await notificationsPlugin.show(
    0,
    "OnPlan",
    "Notificação de teste!",
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'onplan_channel',
        'OnPlan Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}


class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    String path = p.join(await getDatabasesPath(), 'onplan.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            priority INTEGER,
            date TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertTask(Task task) async {
    final db = await database;

    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getTasks() async {
    final db = await database;

    final List<Map<String, dynamic>> maps =
        await db.query('tasks');

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  Future<void> deleteTask(int id) async {
    final db = await database;

    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings =
      InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(settings);

  notificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();

  runApp(OnPlanApp());
}

Future<void> scheduleNotification(
  int id,
  String title,
  String body,
  DateTime scheduledDate,
) async {
  await notificationsPlugin.zonedSchedule(
    id,
    title,
    body,
    tz.TZDateTime.from(scheduledDate, tz.local),

    const NotificationDetails(
      android: AndroidNotificationDetails(
        'onplan_channel',
        'OnPlan Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),

    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

class OnPlanApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnPlan',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Widget getPage() {
  switch (_selectedIndex) {
    case 0:
      return CalendarPage();
    case 1:
      return TasksPage();
    case 2:
      return PomodoroPage();
    default:
      return CalendarPage();
  }
}

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OnPlan')),
      body: getPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Calendário"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Tarefas"),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: "Pomodoro"),
        ],
      ),
    );
  }
}

//////////////////// CALENDÁRIO ////////////////////

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime today = DateTime.now();

  List<Task> tasks = [];

  List<Task> getTasksForDay(DateTime day) {
  return tasks.where((task) {
    return task.date.year == day.year &&
        task.date.month == day.month &&
        task.date.day == day.day;
  }).toList();
}

  Color getPriorityColor(List<Task> dayTasks) {
  if (dayTasks.any((task) => task.priority == 3)) {
    return Colors.red;
  }

  if (dayTasks.any((task) => task.priority == 2)) {
    return Colors.orange;
  }

  return Colors.green;
}

  String getPriorityText(int priority) {
    switch (priority) {
      case 3:
        return "Alta";
      case 2:
        return "Média";
      default:
        return "Baixa";
    }
  }

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  

  Future<void> loadTasks() async {
    tasks = await DatabaseHelper.instance.getTasks();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedTasks = getTasksForDay(today);
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TableCalendar(
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dayTasks = getTasksForDay(day);

                if (dayTasks.isNotEmpty) {
                  return Container(
                    margin: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: getPriorityColor(dayTasks),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                return null;
              },
            ),
            focusedDay: today,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),

            selectedDayPredicate: (day) {
              return isSameDay(today, day);
            },

            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                today = selectedDay;
              });
            },
          ),

          SizedBox(height: 20),

          Text(
            "Dia selecionado: ${today.day}/${today.month}/${today.year}",
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 20),

          Expanded(
            child: selectedTasks.isEmpty
                ? Center(
                    child: Text("Sem tarefas neste dia"),
                  )
                : ListView.builder(
                    itemCount: selectedTasks.length,
                    itemBuilder: (context, index) {
                      final task = selectedTasks[index];

                      return Card(
                        child: ListTile(
                          title: Text(task.title),

                          subtitle: Text(
                            "Prioridade: ${getPriorityText(task.priority)}",
                          ),

                          trailing: Icon(
                            Icons.circle,
                            color: getPriorityColor([task]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

//////////////////// TAREFAS ////////////////////

class Task {
  int? id;
  String title;
  int priority;
  DateTime date;

  Task({
    this.id,
    required this.title,
    required this.priority,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'priority': priority,
      'date': date.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      priority: map['priority'],
      date: DateTime.parse(map['date']),
    );
  }
}

class TasksPage extends StatefulWidget {
  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Task> tasks = [];

  final TextEditingController controller = TextEditingController();
  int selectedPriority = 1;
  DateTime selectedDate = DateTime.now();

  void addTask() async {
  if (controller.text.isEmpty) return;

  Task task = Task(
    title: controller.text,
    priority: selectedPriority,
    date: selectedDate,
  );

  await DatabaseHelper.instance.insertTask(task);

  try {
    await scheduleNotification(
      task.hashCode,
      "Lembrete OnPlan",
      "Tens a tarefa: ${task.title}",
      task.date.subtract(Duration(days: 3)),
    );
  } catch (e) {
    print("Erro ao agendar notificação: $e");
  }
  controller.clear();
  await loadTasks(); 
}

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    tasks = await DatabaseHelper.instance.getTasks();

    setState(() {});
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      );

      if (picked != null) {
        setState(() {
          selectedDate = picked;
        });
      }
    }


  Color getPriorityColor(int priority) {
    switch (priority) {
      case 3:
        return Colors.red;
      case 2:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String getPriorityText(int priority) {
    switch (priority) {
      case 3:
        return "Alta";
      case 2:
        return "Média";
      default:
        return "Baixa";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: "Nova tarefa"),
          ),

          SizedBox(height: 10),

          DropdownButton<int>(
            value: selectedPriority,
            items: [
              DropdownMenuItem(value: 1, child: Text("Baixa")),
              DropdownMenuItem(value: 2, child: Text("Média")),
              DropdownMenuItem(value: 3, child: Text("Alta")),
            ],
            onChanged: (value) {
              setState(() => selectedPriority = value!);
            },
          ),

          ElevatedButton(
            onPressed: pickDate,
            child: Text("Escolher Data"),
          ),

          SizedBox(height: 10),

          Text(
            "Data: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
          ),

          ElevatedButton(
            onPressed: addTask,
            child: Text("Adicionar"),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];

                return ListTile(
                  title: Text(task.title),
                  leading: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await DatabaseHelper.instance.deleteTask(task.id!);

                    loadTasks();
                  },
                ),
                  subtitle: Text(
                    "${task.date.day}/${task.date.month}/${task.date.year}",
                  ),
                  trailing: Text(
                    getPriorityText(task.priority),
                    style: TextStyle(
                      color: getPriorityColor(task.priority),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//////////////////// POMODORO ////////////////////

class PomodoroPage extends StatefulWidget {
  @override
  _PomodoroPageState createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  int timeLeft = 1500;
  int initialTime = 1500;

  bool isRunning = false;



  final TextEditingController timeController =
      TextEditingController(text: "25");

  int calculateRecommendedTime(Task task) {
    final daysLeft = task.date.difference(DateTime.now()).inDays;

    int minutes = 25;

    // baseado nos dias
    if (daysLeft <= 1) {
      minutes += 60;
    } else if (daysLeft <= 3) {
      minutes += 40;
    } else if (daysLeft <= 7) {
      minutes += 20;
    }

    // baseado na prioridade
    if (task.priority == 3) {
      minutes += 30;
    } else if (task.priority == 2) {
      minutes += 15;
    }

    return minutes;
  }

  List<Task> tasks = [];
  Task? selectedTask;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    tasks = await DatabaseHelper.instance.getTasks();

    setState(() {});
  }

  void startTimer() async {
    int minutes = int.tryParse(timeController.text) ?? 25;

    setState(() {
      initialTime = minutes * 60;
      timeLeft = initialTime;
      isRunning = true;
    });

    runTimer();
  }

  void runTimer() async {
    while (timeLeft > 0 && isRunning) {
      await Future.delayed(Duration(seconds: 1));

      if (!isRunning) break;

      setState(() {
        timeLeft--;
      });
    }
  }

  void pauseTimer() {
    setState(() {
      isRunning = false;
    });
  }

  void continueTimer() {
    setState(() {
      isRunning = true;
    });

    runTimer();
  }

  void resetTimer() {
    setState(() {
      isRunning = false;
      timeLeft = initialTime;
    });
  }

  String formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;

    return "$min:${sec.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButton<Task>(
            value: selectedTask,
            hint: Text("Selecionar tarefa"),
            isExpanded: true,
            items: tasks.map((task) {
              return DropdownMenuItem(
                value: task,
                child: Text(task.title),
              );
            }).toList(),
            onChanged: (task) {
              if (task == null) return;

              int recommended =
                  calculateRecommendedTime(task);

              setState(() {
                selectedTask = task;

                timeController.text =
                    recommended.toString();
              });
            },
          ),
          TextField(
            controller: timeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Tempo do foco (minutos)",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 30),

          Text(
            formatTime(timeLeft),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: startTimer,
                child: Text("Iniciar"),
              ),

              SizedBox(width: 10),

              ElevatedButton(
                onPressed: pauseTimer,
                child: Text("Pausar"),
              ),

              SizedBox(width: 10),

              ElevatedButton(
                onPressed: continueTimer,
                child: Text("Continuar"),
              ),
            ],
          ),

          SizedBox(height: 15),

          ElevatedButton(
            onPressed: resetTimer,
            child: Text("Reiniciar"),
          ),

          SizedBox(height: 20),

          Text(
            "Modo Foco ativo",
            style: TextStyle(fontSize: 16),
          ),

          ElevatedButton(
            onPressed: testNotification,
            child: Text("Testar Notificação"),
          ),
        ],
      ),
    );
  }
}