enum RatingRules {
    static func validated(_ rating: Int?, for status: ViewingStatus) -> Int? {
        guard status.allowsRating, let rating, (1...5).contains(rating) else {
            return nil
        }
        return rating
    }
}
