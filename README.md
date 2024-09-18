# Laravel Deployment Script

This is a Bash script for deploying Laravel applications to a server. It automates the deployment process by asking for necessary information and configuring the server environment.

## Features

- Interactive deployment process
- Automatic installation of required packages
- Nginx server block configuration
- MySQL database creation (optional)
- Let's Encrypt SSL certificate setup (optional)
- Progress tracking and colorized output

## Requirements

- A server running Ubuntu 18.04 or later
- A Laravel application with a Git repository
- A user with sudo privileges on the server

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/PatrickMamsery/laravel-deployment-script.git
   ```
2. Change into the repository directory:
   ```
   cd laravel-deployment-script
   ```
3. Make the script executable:
   ```
   chmod +x deploy-laravel.sh
   ```
4. Run the script:
   ```
   ./deploy-laravel.sh
   ```
5. Follow the prompts to provide the required information.

## Configuration

You can customize the deployment process by editing the script. The script is well-commented, making it easy to understand and modify according to your needs.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter any problems or have any questions, please open an issue on the GitHub repository.

<!-- ## License

This script is distributed under the XYZ License. See the [LICENSE](LICENSE) file for details. -->

## Acknowledgements

Thank you to all the contributors who have helped to improve this script.

If you find this script helpful, please consider giving it a star on GitHub!