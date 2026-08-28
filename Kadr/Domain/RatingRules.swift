enum RatingRules {
    static func validated(_ rating: Int?) -> Int? {
        guard let rating, (1...5).contains(rating) else {
            return nil
        }
        return rating
    }
}
