import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// AuthService provides authentication helpers.
class AuthService {
  /// Signs in the user with Google and Firebase Authentication.
  ///
  /// Flow:
  /// - Launches the Google account picker/sign-in UI
  /// - Retrieves the Google `idToken` and `accessToken`
  /// - Exchanges them for a Firebase credential
  /// - Signs in to Firebase and returns the Firebase [User]
  ///
  /// Returns the [User] on success, or `null` if the user cancels the flow.
  static Future<User?> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // The user canceled the sign-in
      return null;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final String? idToken = googleAuth.idToken;
    final String? accessToken = googleAuth.accessToken;

    if (idToken == null && accessToken == null) {
      // Neither token present, cannot proceed
      throw FirebaseAuthException(
        code: 'missing-google-tokens',
        message: 'Google Sign-In did not return idToken or accessToken.',
      );
    }

    // Create a new credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );

    // Once signed in, return the UserCredential
    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    return userCredential.user;
  }
}
