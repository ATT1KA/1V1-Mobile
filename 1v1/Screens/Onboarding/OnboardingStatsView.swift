import SwiftUI

struct OnboardingStatsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Text("Tell us about your gaming experience")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This helps us create your personalized gaming profile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Gaming Experience
                VStack(spacing: 16) {
                    Text("How long have you been gaming?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        ForEach(GamingExperience.allCases, id: \.self) { experience in
                            Button(action: {
                                coordinator.onboardingData.gamingExperience = experience
                            }) {
                                HStack {
                                    Text(experience.displayName)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if coordinator.onboardingData.gamingExperience == experience {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(coordinator.onboardingData.gamingExperience == experience ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(coordinator.onboardingData.gamingExperience == experience ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Favorite Genres
                VStack(spacing: 16) {
                    Text("What are your favorite game genres?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Select all that apply")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(GameGenre.allCases, id: \.self) { genre in
                            Button(action: {
                                if coordinator.onboardingData.favoriteGenres.contains(genre) {
                                    coordinator.onboardingData.favoriteGenres.remove(genre)
                                } else {
                                    coordinator.onboardingData.favoriteGenres.insert(genre)
                                }
                            }) {
                                HStack {
                                    Text(genre.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if coordinator.onboardingData.favoriteGenres.contains(genre) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(coordinator.onboardingData.favoriteGenres.contains(genre) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(coordinator.onboardingData.favoriteGenres.contains(genre) ? Color.blue : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Play Time
                VStack(spacing: 16) {
                    Text("How much time do you spend gaming per week?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        ForEach(PlayTime.allCases, id: \.self) { playTime in
                            Button(action: {
                                coordinator.onboardingData.playTimePerWeek = playTime
                            }) {
                                HStack {
                                    Text(playTime.displayName)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if coordinator.onboardingData.playTimePerWeek == playTime {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(coordinator.onboardingData.playTimePerWeek == playTime ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(coordinator.onboardingData.playTimePerWeek == playTime ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Skill Level
                VStack(spacing: 16) {
                    Text("How would you rate your gaming skill level?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        ForEach(SkillLevel.allCases, id: \.self) { skillLevel in
                            Button(action: {
                                coordinator.onboardingData.skillLevel = skillLevel
                            }) {
                                HStack {
                                    Text(skillLevel.displayName)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if coordinator.onboardingData.skillLevel == skillLevel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(coordinator.onboardingData.skillLevel == skillLevel ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(coordinator.onboardingData.skillLevel == skillLevel ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Complete Stats Button
                Button(action: {
                    coordinator.onboardingData.hasCompletedStats = true
                }) {
                    HStack {
                        Text("Continue to Card Generation")
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isStatsComplete ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isStatsComplete)
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
            .padding()
        }
    }
    
    private var isStatsComplete: Bool {
        return coordinator.onboardingData.gamingExperience != .beginner || 
               !coordinator.onboardingData.favoriteGenres.isEmpty ||
               coordinator.onboardingData.playTimePerWeek != .low ||
               coordinator.onboardingData.skillLevel != .novice
    }
}
