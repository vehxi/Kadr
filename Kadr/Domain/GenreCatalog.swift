import Foundation

struct GenreDefinition: Sendable {
    let id: String
    let englishName: String
    let russianName: String

    func name(for locale: Locale) -> String {
        locale.language.languageCode?.identifier == "ru" ? russianName : englishName
    }
}

enum GenreCatalog {
    static let definitions: [GenreDefinition] = [
        .init(id: "action", englishName: "Action", russianName: "Боевик"),
        .init(id: "adventure", englishName: "Adventure", russianName: "Приключения"),
        .init(id: "animation", englishName: "Animation", russianName: "Анимация"),
        .init(id: "anime", englishName: "Anime", russianName: "Аниме"),
        .init(id: "biography", englishName: "Biography", russianName: "Биография"),
        .init(id: "comedy", englishName: "Comedy", russianName: "Комедия"),
        .init(id: "crime", englishName: "Crime", russianName: "Криминал"),
        .init(id: "documentary", englishName: "Documentary", russianName: "Документальный"),
        .init(id: "drama", englishName: "Drama", russianName: "Драма"),
        .init(id: "family", englishName: "Family", russianName: "Семейный"),
        .init(id: "fantasy", englishName: "Fantasy", russianName: "Фэнтези"),
        .init(id: "film-noir", englishName: "Film Noir", russianName: "Нуар"),
        .init(id: "history", englishName: "History", russianName: "История"),
        .init(id: "horror", englishName: "Horror", russianName: "Ужасы"),
        .init(id: "music", englishName: "Music", russianName: "Музыка"),
        .init(id: "musical", englishName: "Musical", russianName: "Мюзикл"),
        .init(id: "mystery", englishName: "Mystery", russianName: "Детектив"),
        .init(id: "romance", englishName: "Romance", russianName: "Романтика"),
        .init(id: "science-fiction", englishName: "Science Fiction", russianName: "Фантастика"),
        .init(id: "sport", englishName: "Sport", russianName: "Спорт"),
        .init(id: "thriller", englishName: "Thriller", russianName: "Триллер"),
        .init(id: "war", englishName: "War", russianName: "Военный"),
        .init(id: "western", englishName: "Western", russianName: "Вестерн"),
        .init(id: "superhero", englishName: "Superhero", russianName: "Супергеройский"),
        .init(id: "martial-arts", englishName: "Martial Arts", russianName: "Боевые искусства"),
        .init(id: "spy", englishName: "Spy", russianName: "Шпионский"),
        .init(id: "heist", englishName: "Heist", russianName: "Ограбление"),
        .init(id: "gangster", englishName: "Gangster", russianName: "Гангстерский"),
        .init(id: "disaster", englishName: "Disaster", russianName: "Катастрофа"),
        .init(id: "survival", englishName: "Survival", russianName: "Выживание"),
        .init(id: "post-apocalyptic", englishName: "Post-Apocalyptic", russianName: "Постапокалипсис"),
        .init(id: "dystopian", englishName: "Dystopian", russianName: "Антиутопия"),
        .init(id: "utopian", englishName: "Utopian", russianName: "Утопия"),
        .init(id: "cyberpunk", englishName: "Cyberpunk", russianName: "Киберпанк"),
        .init(id: "steampunk", englishName: "Steampunk", russianName: "Стимпанк"),
        .init(id: "space-opera", englishName: "Space Opera", russianName: "Космоопера"),
        .init(id: "time-travel", englishName: "Time Travel", russianName: "Путешествия во времени"),
        .init(id: "alternate-history", englishName: "Alternate History", russianName: "Альтернативная история"),
        .init(id: "alien", englishName: "Alien", russianName: "Инопланетяне"),
        .init(id: "robot", englishName: "Robots", russianName: "Роботы"),
        .init(id: "zombie", englishName: "Zombie", russianName: "Зомби"),
        .init(id: "vampire", englishName: "Vampire", russianName: "Вампиры"),
        .init(id: "werewolf", englishName: "Werewolf", russianName: "Оборотни"),
        .init(id: "monster", englishName: "Monster", russianName: "Монстры"),
        .init(id: "kaiju", englishName: "Kaiju", russianName: "Кайдзю"),
        .init(id: "slasher", englishName: "Slasher", russianName: "Слэшер"),
        .init(id: "body-horror", englishName: "Body Horror", russianName: "Боди-хоррор"),
        .init(id: "folk-horror", englishName: "Folk Horror", russianName: "Фолк-хоррор"),
        .init(id: "gothic", englishName: "Gothic", russianName: "Готика"),
        .init(id: "cosmic-horror", englishName: "Cosmic Horror", russianName: "Космический ужас"),
        .init(id: "found-footage", englishName: "Found Footage", russianName: "Найденная плёнка"),
        .init(id: "psychological", englishName: "Psychological", russianName: "Психологический"),
        .init(id: "supernatural", englishName: "Supernatural", russianName: "Сверхъестественное"),
        .init(id: "paranormal", englishName: "Paranormal", russianName: "Паранормальное"),
        .init(id: "dark-fantasy", englishName: "Dark Fantasy", russianName: "Тёмное фэнтези"),
        .init(id: "urban-fantasy", englishName: "Urban Fantasy", russianName: "Городское фэнтези"),
        .init(id: "epic-fantasy", englishName: "Epic Fantasy", russianName: "Эпическое фэнтези"),
        .init(id: "fairy-tale", englishName: "Fairy Tale", russianName: "Сказка"),
        .init(id: "mythology", englishName: "Mythology", russianName: "Мифология"),
        .init(id: "satire", englishName: "Satire", russianName: "Сатира"),
        .init(id: "parody", englishName: "Parody", russianName: "Пародия"),
        .init(id: "black-comedy", englishName: "Black Comedy", russianName: "Чёрная комедия"),
        .init(id: "romantic-comedy", englishName: "Romantic Comedy", russianName: "Романтическая комедия"),
        .init(id: "sitcom", englishName: "Sitcom", russianName: "Ситком"),
        .init(id: "stand-up", englishName: "Stand-Up", russianName: "Стендап"),
        .init(id: "teen", englishName: "Teen", russianName: "Подростковый"),
        .init(id: "coming-of-age", englishName: "Coming-of-Age", russianName: "Взросление"),
        .init(id: "slice-of-life", englishName: "Slice of Life", russianName: "Повседневность"),
        .init(id: "road-movie", englishName: "Road Movie", russianName: "Роуд-муви"),
        .init(id: "buddy", englishName: "Buddy", russianName: "Бадди-муви"),
        .init(id: "melodrama", englishName: "Melodrama", russianName: "Мелодрама"),
        .init(id: "tragedy", englishName: "Tragedy", russianName: "Трагедия"),
        .init(id: "historical-drama", englishName: "Historical Drama", russianName: "Историческая драма"),
        .init(id: "period-drama", englishName: "Period Drama", russianName: "Костюмная драма"),
        .init(id: "medical", englishName: "Medical", russianName: "Медицинский"),
        .init(id: "legal", englishName: "Legal", russianName: "Юридический"),
        .init(id: "political", englishName: "Political", russianName: "Политический"),
        .init(id: "military", englishName: "Military", russianName: "Армейский"),
        .init(id: "neo-noir", englishName: "Neo-Noir", russianName: "Неонуар"),
        .init(id: "techno-thriller", englishName: "Techno-Thriller", russianName: "Технотриллер"),
        .init(id: "psychological-thriller", englishName: "Psychological Thriller", russianName: "Психологический триллер"),
        .init(id: "crime-thriller", englishName: "Crime Thriller", russianName: "Криминальный триллер"),
        .init(id: "art-house", englishName: "Art House", russianName: "Артхаус"),
        .init(id: "experimental", englishName: "Experimental", russianName: "Экспериментальный"),
        .init(id: "independent", englishName: "Independent", russianName: "Независимое кино"),
        .init(id: "short", englishName: "Short", russianName: "Короткометражный"),
        .init(id: "silent", englishName: "Silent", russianName: "Немое кино"),
        .init(id: "anthology", englishName: "Anthology", russianName: "Антология"),
        .init(id: "mockumentary", englishName: "Mockumentary", russianName: "Псевдодокументальный"),
        .init(id: "concert", englishName: "Concert", russianName: "Концерт"),
        .init(id: "reality-tv", englishName: "Reality TV", russianName: "Реалити-шоу"),
        .init(id: "talk-show", englishName: "Talk Show", russianName: "Ток-шоу"),
        .init(id: "game-show", englishName: "Game Show", russianName: "Телевикторина"),
        .init(id: "news", englishName: "News", russianName: "Новости"),
        .init(id: "educational", englishName: "Educational", russianName: "Образовательный"),
        .init(id: "travel", englishName: "Travel", russianName: "Путешествия"),
        .init(id: "cooking", englishName: "Cooking", russianName: "Кулинарный"),
        .init(id: "nature", englishName: "Nature", russianName: "Природа"),
        .init(id: "true-crime", englishName: "True Crime", russianName: "Реальные преступления"),
        .init(id: "soap-opera", englishName: "Soap Opera", russianName: "Мыльная опера"),
        .init(id: "telenovela", englishName: "Telenovela", russianName: "Теленовелла"),
        .init(id: "miniseries", englishName: "Miniseries", russianName: "Мини-сериал"),
        .init(id: "kids", englishName: "Kids", russianName: "Детский")
    ]

    static func definition(id: String?) -> GenreDefinition? {
        guard let id else { return nil }
        return definitions.first { $0.id == id }
    }

    static func definition(matching name: String) -> GenreDefinition? {
        let normalizedName = TextNormalizer.normalize(name)
        return definitions.first {
            TextNormalizer.normalize($0.englishName) == normalizedName
                || TextNormalizer.normalize($0.russianName) == normalizedName
        }
    }
}
