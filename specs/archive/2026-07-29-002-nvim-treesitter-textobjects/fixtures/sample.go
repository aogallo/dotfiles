package fixtures

// Role names are intentionally grouped to validate native parenthesis textobjects.
const (
	RoleAdmin  = "admin"
	RoleEditor = "editor"
	RoleViewer = "viewer"
)

// User stores account metadata for textobject validation.
type User struct {
	Name  string
	Roles []string
}

// HasRole reports whether the user has the requested role.
func HasRole(user User, role string) bool {
	for _, currentRole := range user.Roles {
		if currentRole == role {
			return true
		}
	}

	return false
}

func FormatUser(user User, prefix string, suffix string) string {
	if HasRole(user, RoleAdmin) {
		return prefix + user.Name + suffix
	}

	return user.Name
}
