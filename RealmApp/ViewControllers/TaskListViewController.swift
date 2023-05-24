//
//  TaskListsViewController.swift
//  RealmApp
//
//  Created by Alexey Efimov on 02.07.2018.
//  Copyright © 2018 Alexey Efimov. All rights reserved.
//

import UIKit
import RealmSwift

enum SortType {
    case date
    case alphabetical
}

final class TaskListViewController: UITableViewController {

    private var taskLists: Results<TaskList>!
    private var sortType: SortType = .date
    private let storageManager = StorageManager.shared
    private let dataManager = DataManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonPressed)
        )
        
        navigationItem.rightBarButtonItem = addButton
        navigationItem.leftBarButtonItem = editButtonItem
        
        taskLists = storageManager.realm.objects(TaskList.self)
        createTempData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        taskLists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskListCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        let taskList = taskLists[indexPath.row]
        content.text = taskList.title
        
        if taskList.tasks.isEmpty {
            content.secondaryText = "0"
            cell.accessoryType = .none
        } else {
            let incompleteTasks = taskList.tasks.filter("isComplete = false")
            
            content.secondaryText = incompleteTasks.isEmpty
            ? ""
            : incompleteTasks.count.formatted()
            
            cell.accessoryType = incompleteTasks.isEmpty
            ? .checkmark
            : .none
        }
        
        cell.contentConfiguration = content
        return cell
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let taskList = taskLists[indexPath.row]
        
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: "Delete"
        ) { [unowned self] _, _, _ in
            storageManager.delete(taskList)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        
        let editAction = UIContextualAction(
            style: .normal,
            title: "Edit"
        ) { [unowned self] _, _, isDone in
            showAlert(with: taskList) {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
            isDone(true)
        }
        editAction.backgroundColor = .orange
        
        if !taskList.tasks.isEmpty {
            let doneActionTitle = taskList.tasks.filter("isComplete = false").isEmpty
            ? "Undone"
            : "Done"
            let doneAction = UIContextualAction(
                style: .normal,
                title: doneActionTitle
            ) { [unowned self] _, _, isDone in
                let incompleteTasks = taskList.tasks.filter("isComplete = false")
                incompleteTasks.isEmpty
                ? storageManager.unDone(taskList)
                : storageManager.done(taskList)
                
                tableView.reloadRows(at: [indexPath], with: .automatic)
                isDone(true)
            }
            doneAction.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            return UISwipeActionsConfiguration(actions: [doneAction, editAction, deleteAction])
        }
        
        return UISwipeActionsConfiguration(actions: [editAction, deleteAction])
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = tableView.indexPathForSelectedRow else { return }
        guard let tasksVC = segue.destination as? TasksViewController else { return }
        let taskList = taskLists[indexPath.row]
        tasksVC.taskList = taskList
    }
    
    // MARK: - IB Actions
    @IBAction func sortingList(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            sortType = .date
        default:
            sortType = .alphabetical
        }
        
        sortTasks()
    }
    
    // MARK: - Methods
    @objc private func addButtonPressed() {
        showAlert()
    }
    
    private func createTempData() {
        if !UserDefaults.standard.bool(forKey: "done") {
            dataManager.createTempData { [unowned self] in
                UserDefaults.standard.set(true, forKey: "done")
                tableView.reloadData()
            }
        }
    }
    
    private func sortTasks() {
        switch sortType {
        case .date:
            taskLists = taskLists.sorted(byKeyPath: "date")
        case .alphabetical:
            taskLists = taskLists.sorted(byKeyPath: "title")
        }
        
        tableView.reloadData()
    }
}

// MARK: - AlertController
extension TaskListViewController {
    private func showAlert(with taskList: TaskList? = nil, completion: (() -> Void)? = nil) {
        let alertBuilder = AlertControllerBuilder(
            title: taskList != nil ? "Edit List" : "New List",
            message: "Please set title for new task list"
        )
        
        alertBuilder
            .setTextField(taskList?.title)
            .addAction(
                title: taskList != nil ? "Update List" : "Save List",
                style: .default
            ) { [weak self] newValue, _ in
                if let taskList, let completion {
                    self?.storageManager.edit(taskList, newValue: newValue)
                    completion()
                    return
                }
                
                self?.save(taskList: newValue)
            }
            .addAction(title: "Cancel", style: .destructive)
        
        let alertController = alertBuilder.build()
        present(alertController, animated: true)
    }
    
    private func save(taskList: String) {
        storageManager.save(taskList) { taskList in
            let rowIndex = IndexPath(row: taskLists.index(of: taskList) ?? 0, section: 0)
            tableView.insertRows(at: [rowIndex], with: .automatic)
        }
    }
}
