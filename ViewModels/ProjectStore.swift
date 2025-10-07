import Foundation
import Combine

final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project = Project()

    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var cancellables = Set<AnyCancellable>()

    private var storeURL: URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("Projects").appendingPathExtension("json")
    }

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
        $currentProject
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] project in
                self?.replace(project)
                self?.save()
            }
            .store(in: &cancellables)
    }

    func load() {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            projects = [currentProject]
            return
        }
        do {
            let data = try Data(contentsOf: storeURL)
            let stored = try decoder.decode([Project].self, from: data)
            projects = stored
            if let first = projects.first {
                currentProject = first
            }
        } catch {
            print("Failed to load projects: \(error)")
            projects = [Project()]
            currentProject = projects[0]
        }
    }

    func update(_ project: Project) {
        replace(project)
        currentProject = project
    }

    func createNewProject() {
        let project = Project()
        projects.insert(project, at: 0)
        currentProject = project
        save()
    }

    func delete(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if currentProject.id == project.id {
            currentProject = projects.first ?? Project()
        }
        save()
    }

    func save() {
        do {
            let data = try encoder.encode(projects)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            print("Failed to save projects: \(error)")
        }
    }

    private func replace(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }
}
